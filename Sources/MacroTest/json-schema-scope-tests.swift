import Macros
import Schema

// An internal alias makes accidental public/package witnesses fail to compile.
internal typealias JSONSchemaInternalFixtureType = Schema.JSONSchema

public enum JSONSchemaScopeFixture {}

public extension JSONSchemaScopeFixture {
    @JSONSchema
    struct Identifier: Codable {
        let rawValue: String
    }

    @JSONSchema
    struct Schema: Codable {
        let identifier: Identifier
    }

    @JSONSchema
    struct Envelope: Codable {
        let schema: Schema
    }

    @JSONSchema
    struct ExistingConformance: Codable, JSONSchemaProviding {
        let schema: Schema
    }

    @JSONSchema
    internal struct ExplicitInternal: Codable {
        typealias JSONSchema = JSONSchemaInternalFixtureType
        let value: String
    }

    struct Container {
        @JSONSchema
        struct Value: Codable {
            typealias JSONSchema = JSONSchemaInternalFixtureType
            let count: Int
        }

        @JSONSchema
        enum Choice: String, Codable {
            typealias JSONSchema = JSONSchemaInternalFixtureType
            case first
            case second
        }
    }
}

package enum JSONSchemaPackageFixture {}

package extension JSONSchemaPackageFixture {
    @JSONSchema
    struct Value: Codable {
        let name: String
    }

    struct Container {
        @JSONSchema
        struct Value: Codable {
            typealias JSONSchema = JSONSchemaInternalFixtureType
            let count: Int
        }
    }
}

private enum JSONSchemaScopeTestError: Error {
    case failed(String)
}

func runJSONSchemaScopeTests() throws {
    try expectSchemaFields(
        JSONSchemaScopeFixture.Identifier.self,
        names: ["rawValue"]
    )
    try expectSchemaFields(
        JSONSchemaScopeFixture.Schema.self,
        names: ["identifier"]
    )
    try expectSchemaFields(
        JSONSchemaScopeFixture.Envelope.self,
        names: ["schema"]
    )
    try expectSchemaFields(
        JSONSchemaScopeFixture.ExistingConformance.self,
        names: ["schema"]
    )
    try expectSchemaFields(
        JSONSchemaScopeFixture.ExplicitInternal.self,
        names: ["value"]
    )
    try expectSchemaFields(
        JSONSchemaScopeFixture.Container.Value.self,
        names: ["count"]
    )
    try expectSchemaFields(
        JSONSchemaPackageFixture.Value.self,
        names: ["name"]
    )
    try expectSchemaFields(
        JSONSchemaPackageFixture.Container.Value.self,
        names: ["count"]
    )

    guard case .string(let cases) =
        JSONSchemaScopeFixture.Container.Choice.jsonschema.form,
        cases == ["first", "second"]
    else {
        throw JSONSchemaScopeTestError.failed(
            "nested enum schema must preserve its cases and internal access"
        )
    }

    guard case .object(let envelope, _) =
        JSONSchemaScopeFixture.Envelope.jsonschema.form,
        let schema = envelope.first(where: { $0.name == "schema" }),
        case .object(let fields, _) = schema.schema.form,
        let identifier = fields.first(where: { $0.name == "identifier" }),
        case .object(let identifierFields, _) = identifier.schema.form,
        identifierFields.map(\.name) == ["rawValue"]
    else {
        throw JSONSchemaScopeTestError.failed(
            "nested schemas must resolve the actual sibling types recursively"
        )
    }
}

private func expectSchemaFields<Value: JSONSchemaProviding>(
    _ type: Value.Type,
    names: [String]
) throws {
    guard case .object(let fields, _) = type.jsonschema.form,
          fields.map(\.name) == names
    else {
        throw JSONSchemaScopeTestError.failed(
            "unexpected schema fields for \(type)"
        )
    }
}
