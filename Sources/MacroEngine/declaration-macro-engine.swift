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

    public init(
        kind: DeclarationMacroKind,
        name: String,
        access: String?
    ) {
        self.kind = kind
        self.name = name
        self.access = access
    }

    public var accessPrefix: String {
        access.map { "\($0) " } ?? ""
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
        macroName: String
    ) throws -> [DeclSyntax] {
        try Specification.members(
            in: context(
                for: declaration,
                macroName: macroName
            )
        )
    }

    public static func extensions(
        of declaration: some DeclGroupSyntax,
        type: some TypeSyntaxProtocol,
        macroName: String
    ) throws -> [ExtensionDeclSyntax] {
        let context = try context(
            for: declaration,
            macroName: macroName
        )
        let members = try Specification.extensionMembers(
            in: context
        )

        guard Specification.conformance != nil || !members.isEmpty else {
            return []
        }

        let inheritance = Specification.conformance.map {
            ": \($0)"
        } ?? ""

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
        macroName: String
    ) throws -> DeclarationMacroContext {
        if let value = declaration.as(StructDeclSyntax.self) {
            return try context(
                kind: .struct,
                name: value.name.text,
                modifiers: value.modifiers,
                macroName: macroName
            )
        }

        if let value = declaration.as(EnumDeclSyntax.self) {
            return try context(
                kind: .enum,
                name: value.name.text,
                modifiers: value.modifiers,
                macroName: macroName
            )
        }

        if let value = declaration.as(ClassDeclSyntax.self) {
            return try context(
                kind: .class,
                name: value.name.text,
                modifiers: value.modifiers,
                macroName: macroName
            )
        }

        if let value = declaration.as(ActorDeclSyntax.self) {
            return try context(
                kind: .actor,
                name: value.name.text,
                modifiers: value.modifiers,
                macroName: macroName
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
        macroName: String
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
            access: access(in: modifiers)
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
