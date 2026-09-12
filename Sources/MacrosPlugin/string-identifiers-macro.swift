import Primitives
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum StringIdentifiersMacroError:
    Error,
    CustomStringConvertible
{
    case invalidCasing(String)
    case memberRequiresStaticVar(String)
    case memberRequiresSingleBinding
    case memberRequiresIdentifier
    case memberRequiresSelfType(String)
    case memberMustBeUninitialized(String)

    var description: String {
        switch self {
        case .invalidCasing(let expression):
            "@StringIdentifiers casing must be a Casing case such as .camel, .snake, or .dot. Invalid expression: \(expression)"

        case .memberRequiresStaticVar(let name):
            "@StringIdentifiers member '\(name)' must be declared as static var."

        case .memberRequiresSingleBinding:
            "@StringIdentifiers members must declare exactly one property per declaration."

        case .memberRequiresIdentifier:
            "@StringIdentifiers members must use an identifier property name."

        case .memberRequiresSelfType(let name):
            "@StringIdentifiers member '\(name)' must have type Self."

        case .memberMustBeUninitialized(let name):
            "@StringIdentifiers member '\(name)' must not provide an initializer or accessor block."
        }
    }
}

public struct StringIdentifiersMacro: MemberAttributeMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo _: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let variable = member.as(
            VariableDeclSyntax.self
        ) else {
            return []
        }

        let casing = try parseCasing(
            from: node
        )

        if let casing {
            return [
                AttributeSyntax(
                    stringLiteral: "@_StringIdentifier(casing: .\(casing.rawValue))"
                ),
            ]
        }

        return [
            AttributeSyntax(
                stringLiteral: "@_StringIdentifier"
            ),
        ]
    }
}

public struct StringIdentifierMemberMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in _: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variable = declaration.as(
            VariableDeclSyntax.self
        ) else {
            return []
        }

        guard variable.bindings.count == 1,
              let binding = variable.bindings.first
        else {
            throw StringIdentifiersMacroError.memberRequiresSingleBinding
        }

        guard let identifier = binding.pattern.as(
            IdentifierPatternSyntax.self
        ) else {
            throw StringIdentifiersMacroError.memberRequiresIdentifier
        }

        let name = identifier.identifier.text

        guard variable.bindingSpecifier.text == "var",
              variable.modifiers.contains(where: {
                  $0.name.text == "static"
              })
        else {
            throw StringIdentifiersMacroError.memberRequiresStaticVar(
                name
            )
        }

        guard binding.typeAnnotation?.type.trimmedDescription == "Self" else {
            throw StringIdentifiersMacroError.memberRequiresSelfType(
                name
            )
        }

        guard binding.initializer == nil,
              binding.accessorBlock == nil
        else {
            throw StringIdentifiersMacroError.memberMustBeUninitialized(
                name
            )
        }

        let casing = try parseCasing(
            from: node
        )

        let rawValue = casing.map {
            Case.convert(
                name,
                to: $0
            )
        } ?? name

        return [
            """
            get {
                Self(rawValue: \(literal: rawValue))
            }
            """,
        ]
    }
}

private func parseCasing(
    from attribute: AttributeSyntax
) throws -> Casing? {
    guard case .argumentList(let arguments) = attribute.arguments else {
        return nil
    }

    guard let argument = arguments.first else {
        return nil
    }

    guard argument.label?.text == "casing" else {
        throw StringIdentifiersMacroError.invalidCasing(
            argument.expression.trimmedDescription
        )
    }

    let source = argument.expression.trimmedDescription

    if source == "nil" {
        return nil
    }

    guard
        let name = source
            .split(separator: ".")
            .last
            .map(String.init),
        let casing = Casing(
            rawValue: name
        )
    else {
        throw StringIdentifiersMacroError.invalidCasing(
            source
        )
    }

    return casing
}
