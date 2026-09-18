import MacroEngine
import SwiftSyntax
import SwiftSyntaxBuilder

private enum DeclarationPathProbeSpecification:
    DeclarationMacroSpecification
{
    static let supportedKinds: Set<DeclarationMacroKind> = [
        .struct,
    ]

    static func members(
        in context: DeclarationMacroContext
    ) throws -> [DeclSyntax] {
        let path = context.lexicalPath.joined(separator: ".")

        return [
            DeclSyntax(
                stringLiteral:
                    "static let declarationPath = \"\(path)\""
            ),
        ]
    }
}

private enum DeclarationMacroEngineTestError:
    Error,
    CustomStringConvertible
{
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            message
        }
    }
}

func runDeclarationMacroEngineTests() throws {
    try testExtensionLexicalPath()
    try testNestedNominalLexicalPath()
}

private func testExtensionLexicalPath() throws {
    let declaration = try composeReplyDeclaration()
    let extensionDeclaration = try extensionDeclaration(
        "extension Business.Inferences {}"
    )

    let members = try DeclarationMacroEngine<
        DeclarationPathProbeSpecification
    >.members(
        of: declaration,
        macroName: "DeclarationPathProbe",
        lexicalContext: [
            Syntax(declaration),
            Syntax(extensionDeclaration),
        ]
    )

    try expectDeclarationPath(
        members,
        expected: "Business.Inferences.ComposeReply"
    )
}

private func testNestedNominalLexicalPath() throws {
    let declaration = try composeReplyDeclaration()
    let inferences = try enumDeclaration(
        "enum Inferences {}"
    )
    let business = try enumDeclaration(
        "enum Business {}"
    )

    let members = try DeclarationMacroEngine<
        DeclarationPathProbeSpecification
    >.members(
        of: declaration,
        macroName: "DeclarationPathProbe",
        lexicalContext: [
            Syntax(declaration),
            Syntax(inferences),
            Syntax(business),
        ]
    )

    try expectDeclarationPath(
        members,
        expected: "Business.Inferences.ComposeReply"
    )
}

private func composeReplyDeclaration() throws -> StructDeclSyntax {
    guard let declaration = DeclSyntax(
        stringLiteral: "struct ComposeReply {}"
    ).as(StructDeclSyntax.self) else {
        throw DeclarationMacroEngineTestError.failed(
            "failed to construct declaration probe"
        )
    }

    return declaration
}

private func extensionDeclaration(
    _ source: String
) throws -> ExtensionDeclSyntax {
    guard let declaration = DeclSyntax(
        stringLiteral: source
    ).as(ExtensionDeclSyntax.self) else {
        throw DeclarationMacroEngineTestError.failed(
            "failed to construct extension lexical context"
        )
    }

    return declaration
}

private func enumDeclaration(
    _ source: String
) throws -> EnumDeclSyntax {
    guard let declaration = DeclSyntax(
        stringLiteral: source
    ).as(EnumDeclSyntax.self) else {
        throw DeclarationMacroEngineTestError.failed(
            "failed to construct nominal lexical context"
        )
    }

    return declaration
}

private func expectDeclarationPath(
    _ members: [DeclSyntax],
    expected: String
) throws {
    guard members.count == 1 else {
        throw DeclarationMacroEngineTestError.failed(
            "declaration path probe emitted \(members.count) members"
        )
    }

    let expectedDeclaration =
        "static let declarationPath = \"\(expected)\""

    guard members[0].trimmedDescription == expectedDeclaration else {
        throw DeclarationMacroEngineTestError.failed(
            "expected '\(expectedDeclaration)', received '\(members[0].trimmedDescription)'"
        )
    }
}
