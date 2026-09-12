import Primitives
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum APIMacroError:
    Error,
    CustomStringConvertible
{
    case missingRole
    case unsupportedRole(String)
    case rootRequiresClass
    case rootDoesNotAcceptPropertyConfiguration
    case namespaceRequiresStruct
    case namespaceRequiresRoot

    case invalidArgument(String)
    case invalidPropertyWord(String)
    case invalidCasing(String)
    case invalidOptions(String)

    case invalidProperty(CasedProperty.Error)

    var description: String {
        switch self {
        case .missingRole:
            "@API requires .root or .namespace"

        case .unsupportedRole(let role):
            "Unsupported @API role: \(role)"

        case .rootRequiresClass:
            "@API(.root) currently requires a class declaration"

        case .rootDoesNotAcceptPropertyConfiguration:
            "@API(.root) does not accept property, casing, or options arguments"

        case .namespaceRequiresStruct:
            "@API(.namespace) currently requires a struct declaration"

        case .namespaceRequiresRoot:
            "@API(.namespace) must be nested inside an @API(.root) declaration"

        case .invalidArgument(let argument):
            "Unsupported @API argument: \(argument)"

        case .invalidPropertyWord(let expression):
            """
            @API property words must be plain string literals. \
            Invalid property expression: \(expression)
            """

        case .invalidCasing(let expression):
            """
            @API casing must be a Casing case such as .camel, .snake, or .dot. \
            Invalid casing expression: \(expression)
            """

        case .invalidOptions(let expression):
            """
            @API options must use CasedProperty.Options values such as \
            .reservedKeywords, .rawIdentifiers, .lenient, or an array of them. \
            Invalid options expression: \(expression)
            """

        case .invalidProperty(let error):
            error.description
        }
    }
}

private struct APINamespaceConfiguration {
    let propertyWords: [String]
    let casing: Casing
    let options: CasedProperty.Options
}

private enum APIAttributeRole {
    case root
    case namespace(APINamespaceConfiguration)
}

public struct APIMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        switch try parseRole(node) {
        case .root:
            guard declaration.is(ClassDeclSyntax.self) else {
                throw APIMacroError.rootRequiresClass
            }

            return try namespaceAccessors(
                in: declaration,
                rootExpression: "self"
            )

        case .namespace:
            guard declaration.is(StructDeclSyntax.self) else {
                throw APIMacroError.namespaceRequiresStruct
            }

            guard let rootType = rootTypeName(
                in: context
            ) else {
                throw APIMacroError.namespaceRequiresRoot
            }

            var members: [DeclSyntax] = [
                "fileprivate let root: \(raw: rootType)",
                """
                fileprivate init(root: \(raw: rootType)) {
                    self.root = root
                }
                """,
            ]

            members.append(
                contentsOf: try namespaceAccessors(
                    in: declaration,
                    rootExpression: "root"
                )
            )

            return members
        }
    }
}

private extension APIMacro {
    static func parseRole(
        _ attribute: AttributeSyntax
    ) throws -> APIAttributeRole {
        guard
            case .argumentList(let arguments) = attribute.arguments,
            let first = arguments.first
        else {
            throw APIMacroError.missingRole
        }

        let role =
            first
                .expression
                .trimmedDescription

        if role == ".root" || role.hasSuffix(".root") {
            guard arguments.count == 1 else {
                throw APIMacroError.rootDoesNotAcceptPropertyConfiguration
            }

            return .root
        }

        guard
            role == ".namespace"
                || role.hasSuffix(".namespace")
        else {
            throw APIMacroError.unsupportedRole(
                role
            )
        }

        var propertyWords: [String] = []
        var casing: Casing = .camel
        var options: CasedProperty.Options = []

        var collectingPropertyWords = false

        for argument in arguments.dropFirst() {
            let label =
                argument
                    .label?
                    .text

            switch label {
            case "property":
                collectingPropertyWords = true

                propertyWords.append(
                    try propertyWord(
                        from: argument.expression
                    )
                )

            case "casing":
                collectingPropertyWords = false

                casing = try parseCasing(
                    argument.expression
                )

            case "options":
                collectingPropertyWords = false

                options = try parseOptions(
                    argument.expression
                )

            case nil:
                guard collectingPropertyWords else {
                    throw APIMacroError.invalidArgument(
                        argument.expression.trimmedDescription
                    )
                }

                propertyWords.append(
                    try propertyWord(
                        from: argument.expression
                    )
                )

            default:
                throw APIMacroError.invalidArgument(
                    label
                        ?? argument.expression.trimmedDescription
                )
            }
        }

        return .namespace(
            .init(
                propertyWords: propertyWords,
                casing: casing,
                options: options
            )
        )
    }

    static func propertyWord(
        from expression: ExprSyntax
    ) throws -> String {
        guard
            let literal = expression.as(
                StringLiteralExprSyntax.self
            ),
            literal.segments.count == 1,
            case .stringSegment(let segment) = literal.segments.first
        else {
            throw APIMacroError.invalidPropertyWord(
                expression.trimmedDescription
            )
        }

        return segment.content.text
    }

    static func parseCasing(
        _ expression: ExprSyntax
    ) throws -> Casing {
        let source =
            expression
                .trimmedDescription

        guard
            let name =
                source
                    .split(separator: ".")
                    .last
                    .map(String.init),
            let casing = Casing(
                rawValue: name
            )
        else {
            throw APIMacroError.invalidCasing(
                source
            )
        }

        return casing
    }

    static func parseOptions(
        _ expression: ExprSyntax
    ) throws -> CasedProperty.Options {
        if let array = expression.as(
            ArrayExprSyntax.self
        ) {
            var options: CasedProperty.Options = []

            for element in array.elements {
                options.formUnion(
                    try parseOption(
                        element.expression
                    )
                )
            }

            return options
        }

        return try parseOption(
            expression
        )
    }

    static func parseOption(
        _ expression: ExprSyntax
    ) throws -> CasedProperty.Options {
        let source =
            expression
                .trimmedDescription

        guard
            let name =
                source
                    .split(separator: ".")
                    .last
                    .map(String.init)
        else {
            throw APIMacroError.invalidOptions(
                source
            )
        }

        switch name {
        case "reservedKeywords":
            return .reservedKeywords

        case "rawIdentifiers":
            return .rawIdentifiers

        case "lenient":
            return .lenient

        default:
            throw APIMacroError.invalidOptions(
                source
            )
        }
    }

    static func namespaceAccessors(
        in declaration: some DeclGroupSyntax,
        rootExpression: String
    ) throws -> [DeclSyntax] {
        var result: [DeclSyntax] = []

        for member in declaration.memberBlock.members {
            guard
                let namespace = member.decl.as(
                    StructDeclSyntax.self
                ),
                let role = try namespaceRole(
                    in: namespace.attributes
                ),
                case .namespace(let configuration) = role
            else {
                continue
            }

            let typeName =
                namespace
                    .name
                    .text

            let property = try casedProperty(
                for: typeName,
                configuration: configuration
            )

            let access = accessPrefix(
                namespace.modifiers
            )

            result.append(
                """
                \(raw: access)var \(raw: property.identifier): \(raw: typeName) {
                    \(raw: typeName)(root: \(raw: rootExpression))
                }
                """
            )
        }

        return result
    }

    static func casedProperty(
        for typeName: String,
        configuration: APINamespaceConfiguration
    ) throws -> CasedProperty {
        let words =
            configuration.propertyWords.isEmpty
            ? [typeName]
            : configuration.propertyWords

        do {
            return try CasedProperty(
                words,
                casing: configuration.casing,
                options: configuration.options
            )
        } catch let error as CasedProperty.Error {
            throw APIMacroError.invalidProperty(
                error
            )
        }
    }

    static func namespaceRole(
        in attributes: AttributeListSyntax
    ) throws -> APIAttributeRole? {
        for element in attributes {
            guard
                let attribute = element.as(
                    AttributeSyntax.self
                ),
                isAPIAttribute(
                    attribute
                )
            else {
                continue
            }

            return try parseRole(
                attribute
            )
        }

        return nil
    }

    static func rootTypeName(
        in context: some MacroExpansionContext
    ) -> String? {
        for lexical in context.lexicalContext {
            guard
                let declaration = lexical.as(
                    ClassDeclSyntax.self
                ),
                hasRootAttribute(
                    declaration.attributes
                )
            else {
                continue
            }

            return declaration.name.text
        }

        return nil
    }

    static func hasRootAttribute(
        _ attributes: AttributeListSyntax
    ) -> Bool {
        for element in attributes {
            guard
                let attribute = element.as(
                    AttributeSyntax.self
                ),
                isAPIAttribute(
                    attribute
                ),
                let role = try? parseRole(
                    attribute
                )
            else {
                continue
            }

            if case .root = role {
                return true
            }
        }

        return false
    }

    static func isAPIAttribute(
        _ attribute: AttributeSyntax
    ) -> Bool {
        let name =
            attribute
                .attributeName
                .trimmedDescription

        return
            name == "API"
            || name.hasSuffix(".API")
    }

    static func accessPrefix(
        _ modifiers: DeclModifierListSyntax
    ) -> String {
        for modifier in modifiers {
            switch modifier.name.text {
            case
                "public",
                "package",
                "internal",
                "fileprivate",
                "private":
                return modifier.name.text + " "

            default:
                continue
            }
        }

        return ""
    }
}
