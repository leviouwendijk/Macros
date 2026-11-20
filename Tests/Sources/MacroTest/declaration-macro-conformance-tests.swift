import MacroEngine
import SwiftSyntax
import SwiftSyntaxBuilder

private enum ConformanceOnlyProbeSpecification:
    DeclarationMacroSpecification
{
    static let supportedKinds: Set<DeclarationMacroKind> = [
        .struct,
    ]

    static let conformance: String? = "ProbeContract"

    static func members(
        in _: DeclarationMacroContext
    ) throws -> [DeclSyntax] {
        []
    }
}

private enum ConformanceAndMemberProbeSpecification:
    DeclarationMacroSpecification
{
    static let supportedKinds: Set<DeclarationMacroKind> = [
        .struct,
    ]

    static let conformance: String? = "ProbeContract"

    static func members(
        in _: DeclarationMacroContext
    ) throws -> [DeclSyntax] {
        []
    }

    static func extensionMembers(
        in _: DeclarationMacroContext
    ) throws -> [DeclSyntax] {
        [
            DeclSyntax(
                stringLiteral: "static let marker = true"
            ),
        ]
    }
}

private enum DeclarationMacroConformanceTestError:
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

func runDeclarationMacroConformanceTests() throws {
    let declaration = try conformanceProbeDeclaration()
    let type = TypeSyntax(
        stringLiteral: "ConformanceProbe"
    )

    let requested = try DeclarationMacroEngine<
        ConformanceOnlyProbeSpecification
    >.extensions(
        of: declaration,
        type: type,
        conformingTo: [
            TypeSyntax(
                stringLiteral: "ProbeContract"
            ),
        ],
        macroName: "ConformanceProbe"
    )

    guard
        requested.count == 1,
        requested[0].trimmedDescription ==
            "extension ConformanceProbe: ProbeContract {}"
    else {
        throw DeclarationMacroConformanceTestError.failed(
            "requested conformance was not emitted exactly once"
        )
    }

    let qualified = try DeclarationMacroEngine<
        ConformanceOnlyProbeSpecification
    >.extensions(
        of: declaration,
        type: type,
        conformingTo: [
            TypeSyntax(
                stringLiteral: "Example.ProbeContract"
            ),
        ],
        macroName: "ConformanceProbe"
    )

    guard
        qualified.count == 1,
        qualified[0].trimmedDescription.contains(
            ": ProbeContract"
        )
    else {
        throw DeclarationMacroConformanceTestError.failed(
            "module-qualified requested conformance was not recognized"
        )
    }

    let alreadyConforming = try DeclarationMacroEngine<
        ConformanceOnlyProbeSpecification
    >.extensions(
        of: declaration,
        type: type,
        conformingTo: [],
        macroName: "ConformanceProbe"
    )

    guard alreadyConforming.isEmpty else {
        throw DeclarationMacroConformanceTestError.failed(
            "existing conformance must not be restated"
        )
    }

    let witnessOnly = try DeclarationMacroEngine<
        ConformanceAndMemberProbeSpecification
    >.extensions(
        of: declaration,
        type: type,
        conformingTo: [],
        macroName: "ConformanceProbe"
    )

    guard
        witnessOnly.count == 1,
        !witnessOnly[0].trimmedDescription.contains(
            ": ProbeContract"
        ),
        witnessOnly[0].trimmedDescription.contains(
            "static let marker = true"
        )
    else {
        throw DeclarationMacroConformanceTestError.failed(
            "extension members must survive without restating an existing conformance"
        )
    }
}

private func conformanceProbeDeclaration() throws
    -> StructDeclSyntax
{
    guard let declaration = DeclSyntax(
        stringLiteral: "struct ConformanceProbe {}"
    ).as(StructDeclSyntax.self) else {
        throw DeclarationMacroConformanceTestError.failed(
            "failed to construct conformance probe declaration"
        )
    }

    return declaration
}
