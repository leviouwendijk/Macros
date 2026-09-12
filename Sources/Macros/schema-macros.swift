import Schema

@attached(
    extension,
    conformances: JSONSchemaProviding,
    names: named(jsonschema)
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
