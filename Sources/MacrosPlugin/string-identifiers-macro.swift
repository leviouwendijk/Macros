import Primitives
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

enum StringIdentifiersMacroError:
    Error,
    CustomStringConvertible
{
    case missingNames
    case invalidNameExpression(String)
    case invalidName(String)
    case duplicateName(String)
    case invalidRawValueCasing(String)
    case unsupportedArgument(String)

    var description: String {
        switch self {
        case .missingNames:
            "#StringIdentifiers requires at least one member name."

        case .invalidNameExpression(let expression):
            "#StringIdentifiers member names must be plain string literals. Invalid expression: \(expression)"

        case .invalidName(let name):
            "#StringIdentifiers member name '\(name)' is not a supported Swift identifier."

        case .duplicateName(let name):
            "#StringIdentifiers contains duplicate member name '\(name)'."

        case .invalidRawValueCasing(let expression):
            "#StringIdentifiers rawValueCasing must be nil or a Casing case such as .camel, .snake, or .dot. Invalid expression: \(expression)"

        case .unsupportedArgument(let argument):
            "Unsupported #StringIdentifiers argument: \(argument)"
        }
    }
}

public struct StringIdentifiersMacro: DeclarationMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in _: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        var names: [String] = []
        var rawValueCasing: Casing?

        for argument in node.arguments {
            let label = argument.label?.text

            switch label {
            case nil:
                names.append(
                    try name(
                        from: argument.expression
                    )
                )

            case "rawValueCasing":
                rawValueCasing = try casing(
                    from: argument.expression
                )

            default:
                throw StringIdentifiersMacroError.unsupportedArgument(
                    label ?? argument.expression.trimmedDescription
                )
            }
        }

        guard !names.isEmpty else {
            throw StringIdentifiersMacroError.missingNames
        }

        var seen: Set<String> = []

        return try names.map { name in
            guard seen.insert(name).inserted else {
                throw StringIdentifiersMacroError.duplicateName(
                    name
                )
            }

            let identifier = try escapedIdentifier(
                name
            )

            let rawValue = rawValueCasing.map {
                Case.convert(
                    name,
                    to: $0
                )
            } ?? name

            return """
            static let \(raw: identifier) = Self(
                rawValue: \(literal: rawValue)
            )
            """
        }
    }
}

private extension StringIdentifiersMacro {
    static func name(
        from expression: ExprSyntax
    ) throws -> String {
        guard
            let literal = expression.as(
                StringLiteralExprSyntax.self
            ),
            literal.segments.count == 1,
            case .stringSegment(let segment) = literal.segments.first
        else {
            throw StringIdentifiersMacroError.invalidNameExpression(
                expression.trimmedDescription
            )
        }

        return segment.content.text
    }

    static func casing(
        from expression: ExprSyntax
    ) throws -> Casing? {
        let source = expression.trimmedDescription

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
            throw StringIdentifiersMacroError.invalidRawValueCasing(
                source
            )
        }

        return casing
    }

    static func escapedIdentifier(
        _ name: String
    ) throws -> String {
        guard
            let first = name.first,
            first == "_" || first.isLetter,
            name.dropFirst().allSatisfy({ character in
                character == "_"
                    || character.isLetter
                    || character.isNumber
            })
        else {
            throw StringIdentifiersMacroError.invalidName(
                name
            )
        }

        return "`\(name)`"
    }
}
