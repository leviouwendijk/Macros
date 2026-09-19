import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum DeclarationMacroKind:
    String,
    Sendable,
    Hashable
{
    case `struct`
    case `enum`
    case `class`
    case actor
}

public struct DeclarationMacroContext:
    Sendable,
    Hashable
{
    public let kind: DeclarationMacroKind
    public let name: String
    public let access: String?
    public let lexicalScope: [String]

    public init(
        kind: DeclarationMacroKind,
        name: String,
        access: String?,
        lexicalScope: [String] = []
    ) {
        self.kind = kind
        self.name = name
        self.access = access
        self.lexicalScope = lexicalScope
    }

    public var accessPrefix: String {
        access.map { "\($0) " } ?? ""
    }

    public var lexicalPath: [String] {
        lexicalScope + [name]
    }
}

public protocol DeclarationMacroSpecification {
    static var supportedKinds: Set<DeclarationMacroKind> { get }
    static var conformance: String? { get }

    static func members(
        in context: DeclarationMacroContext
    ) throws -> [DeclSyntax]

    static func extensionMembers(
        in context: DeclarationMacroContext
    ) throws -> [DeclSyntax]
}

public extension DeclarationMacroSpecification {
    static var conformance: String? {
        nil
    }

    static func extensionMembers(
        in _: DeclarationMacroContext
    ) throws -> [DeclSyntax] {
        []
    }
}

public enum DeclarationMacroEngine<
    Specification: DeclarationMacroSpecification
> {
    public static func members(
        of declaration: some DeclGroupSyntax,
        macroName: String,
        lexicalContext: [Syntax] = []
    ) throws -> [DeclSyntax] {
        try Specification.members(
            in: context(
                for: declaration,
                macroName: macroName,
                lexicalContext: lexicalContext
            )
        )
    }

    public static func extensions(
        of declaration: some DeclGroupSyntax,
        type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        macroName: String,
        lexicalContext: [Syntax] = []
    ) throws -> [ExtensionDeclSyntax] {
        let context = try context(
            for: declaration,
            macroName: macroName,
            lexicalContext: lexicalContext
        )
        let members = try Specification.extensionMembers(
            in: context
        )

        let needsConformance: Bool
        if let required = Specification.conformance {
            needsConformance = protocols.contains { protocolType in
                let actual = protocolType.trimmedDescription

                return actual == required
                    || actual.hasSuffix(".\(required)")
            }
        } else {
            needsConformance = false
        }

        guard needsConformance || !members.isEmpty else {
            return []
        }

        let inheritance = needsConformance
            ? ": \(Specification.conformance!)"
            : ""

        let body = members
            .map(\.trimmedDescription)
            .joined(separator: "\n")

        let source: String
        if body.isEmpty {
            source = "extension \(type.trimmedDescription)\(inheritance) {}"
        } else {
            source = """
            extension \(type.trimmedDescription)\(inheritance) {
            \(body)
            }
            """
        }

        guard let value = DeclSyntax(
            stringLiteral: source
        ).as(ExtensionDeclSyntax.self) else {
            throw MacroExpansionErrorMessage(
                "@\(macroName) failed to form its generated extension."
            )
        }

        return [value]
    }
}

private extension DeclarationMacroEngine {
    static func context(
        for declaration: some DeclGroupSyntax,
        macroName: String,
        lexicalContext: [Syntax]
    ) throws -> DeclarationMacroContext {
        if let value = declaration.as(StructDeclSyntax.self) {
            return try context(
                kind: .struct,
                name: identifierName(value.name),
                modifiers: value.modifiers,
                macroName: macroName,
                lexicalContext: lexicalContext
            )
        }

        if let value = declaration.as(EnumDeclSyntax.self) {
            return try context(
                kind: .enum,
                name: identifierName(value.name),
                modifiers: value.modifiers,
                macroName: macroName,
                lexicalContext: lexicalContext
            )
        }

        if let value = declaration.as(ClassDeclSyntax.self) {
            return try context(
                kind: .class,
                name: identifierName(value.name),
                modifiers: value.modifiers,
                macroName: macroName,
                lexicalContext: lexicalContext
            )
        }

        if let value = declaration.as(ActorDeclSyntax.self) {
            return try context(
                kind: .actor,
                name: identifierName(value.name),
                modifiers: value.modifiers,
                macroName: macroName,
                lexicalContext: lexicalContext
            )
        }

        throw MacroExpansionErrorMessage(
            "@\(macroName) supports only nominal type declarations."
        )
    }

    static func context(
        kind: DeclarationMacroKind,
        name: String,
        modifiers: DeclModifierListSyntax,
        macroName: String,
        lexicalContext: [Syntax]
    ) throws -> DeclarationMacroContext {
        guard Specification.supportedKinds.contains(kind) else {
            let supported = Specification.supportedKinds
                .map(\.rawValue)
                .sorted()
                .joined(separator: ", ")

            throw MacroExpansionErrorMessage(
                "@\(macroName) supports only: \(supported)."
            )
        }

        return DeclarationMacroContext(
            kind: kind,
            name: name,
            access: access(in: modifiers),
            lexicalScope: try lexicalScope(
                for: name,
                in: lexicalContext,
                macroName: macroName
            )
        )
    }

    static func lexicalScope(
        for declarationName: String,
        in lexicalContext: [Syntax],
        macroName: String
    ) throws -> [String] {
        var contexts = lexicalContext[...]

        if
            let first = contexts.first,
            nominalName(in: first) == declarationName
        {
            contexts = contexts.dropFirst()
        }

        var components: [String] = []

        for syntax in contexts.reversed() {
            if let declaration = syntax.as(ExtensionDeclSyntax.self) {
                guard let path = typePath(declaration.extendedType) else {
                    throw MacroExpansionErrorMessage(
                        "@\(macroName) could not derive a lexical path from extension type '\(declaration.extendedType.trimmedDescription)'."
                    )
                }

                components.append(contentsOf: path)
                continue
            }

            if let name = nominalName(in: syntax) {
                components.append(name)
            }
        }

        return components
    }

    static func nominalName(
        in syntax: Syntax
    ) -> String? {
        if let value = syntax.as(StructDeclSyntax.self) {
            return identifierName(value.name)
        }

        if let value = syntax.as(EnumDeclSyntax.self) {
            return identifierName(value.name)
        }

        if let value = syntax.as(ClassDeclSyntax.self) {
            return identifierName(value.name)
        }

        if let value = syntax.as(ActorDeclSyntax.self) {
            return identifierName(value.name)
        }

        if let value = syntax.as(ProtocolDeclSyntax.self) {
            return identifierName(value.name)
        }

        return nil
    }

    static func typePath(
        _ type: TypeSyntax
    ) -> [String]? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return [
                identifierName(identifier.name),
            ]
        }

        if let member = type.as(MemberTypeSyntax.self) {
            guard let base = typePath(member.baseType) else {
                return nil
            }

            return base + [
                identifierName(member.name),
            ]
        }

        return nil
    }

    static func identifierName(
        _ token: TokenSyntax
    ) -> String {
        let source = token.trimmedDescription

        guard
            source.first == "`",
            source.last == "`"
        else {
            return token.text
        }

        return String(
            source.dropFirst().dropLast()
        )
    }

    static func access(
        in modifiers: DeclModifierListSyntax
    ) -> String? {
        let names: Set<String> = [
            "open",
            "public",
            "package",
            "internal",
            "fileprivate",
            "private",
        ]

        return modifiers
            .map { $0.name.text }
            .first(where: names.contains)
    }
}
