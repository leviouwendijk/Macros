import Schema

@attached(
    member,
    names: named(jsonschema)
)
@attached(
    extension,
    conformances: JSONSchemaProviding
)
public macro JSONSchema() =
    #externalMacro(
        module: "MacrosPlugin",
        type: "JSONSchemaMacro"
    )

@attached(peer, names: arbitrary)
public macro Schema(
    required: Bool? = nil
) =
    #externalMacro(
        module: "MacrosPlugin",
        type: "SchemaPropertyMacro"
    )
