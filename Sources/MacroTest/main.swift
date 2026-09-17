import Foundation
import Macros
import Schema

@JSONSchema
private enum EscapedStringEnum:
    String,
    Codable,
    Equatable
{
    case ordinary
    case `internal`
    case `private`
    case explicit = "explicit-value"
}

@JSONSchema
private struct EscapedProperty:
    Codable,
    Equatable
{
    let `default`: String

    enum CodingKeys:
        String,
        CodingKey
    {
        case `default`
    }
}

@JSONSchema
private enum EscapedAssociatedEnum:
    Codable,
    Equatable
{
    case `default`(
        `internal`: String
    )
}

private enum MacroTestError:
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

private func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    guard condition() else {
        throw MacroTestError.failed(message)
    }
}

@main
private struct MacroTest {
    static func main() throws {
        try testStringEnum()
        try testEscapedProperty()
        try testAssociatedEnum()

        print("macrotest: pass")
    }

    private static func testStringEnum() throws {
        guard case .string(let cases) = EscapedStringEnum.jsonschema.form else {
            throw MacroTestError.failed(
                "escaped String enum did not produce a string schema"
            )
        }

        try expect(
            cases == [
                "ordinary",
                "internal",
                "private",
                "explicit-value",
            ],
            "escaped String enum schema values must use semantic identifiers"
        )

        try expect(
            EscapedStringEnum.internal.rawValue == "internal",
            "escaped String enum raw value must be the semantic identifier"
        )

        let encoded = try JSONEncoder().encode(
            EscapedStringEnum.internal
        )

        try expect(
            String(decoding: encoded, as: UTF8.self) == "\"internal\"",
            "escaped String enum Codable encoding must use the semantic identifier"
        )

        let decoded = try JSONDecoder().decode(
            EscapedStringEnum.self,
            from: Data("\"internal\"".utf8)
        )

        try expect(
            decoded == .internal,
            "escaped String enum Codable decoding must accept the semantic identifier"
        )
    }

    private static func testEscapedProperty() throws {
        guard case .object(let properties, _) = EscapedProperty.jsonschema.form else {
            throw MacroTestError.failed(
                "escaped property probe did not produce an object schema"
            )
        }

        try expect(
            properties.contains { $0.name == "default" },
            "escaped property schema must use the semantic identifier"
        )

        let decoded = try JSONDecoder().decode(
            EscapedProperty.self,
            from: Data(#"{"default":"value"}"#.utf8)
        )

        try expect(
            decoded.default == "value",
            "escaped CodingKey must decode from its semantic identifier"
        )
    }

    private static func testAssociatedEnum() throws {
        guard case .oneOf(let variants) = EscapedAssociatedEnum.jsonschema.form else {
            throw MacroTestError.failed(
                "escaped associated enum did not produce a oneOf schema"
            )
        }

        guard let variant = variants.first,
              case .object(let caseProperties, _) = variant.form,
              let caseProperty = caseProperties.first(where: {
                  $0.name == "default"
              }),
              case .object(let payloadProperties, _) = caseProperty.schema.form
        else {
            throw MacroTestError.failed(
                "escaped associated enum schema does not contain semantic case structure"
            )
        }

        try expect(
            payloadProperties.contains { $0.name == "internal" },
            "escaped associated-value label must use the semantic identifier"
        )

        let decoded = try JSONDecoder().decode(
            EscapedAssociatedEnum.self,
            from: Data(#"{"default":{"internal":"value"}}"#.utf8)
        )

        switch decoded {
        case .default(let value):
            try expect(
                value == "value",
                "escaped associated enum Codable decoding must use semantic identifiers"
            )
        }
    }
}
