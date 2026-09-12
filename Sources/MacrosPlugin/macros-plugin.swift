import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        JSONSchemaMacro.self,
        SchemaPropertyMacro.self,
        APIMacro.self,
        StringIdentifiersMacro.self,
    ]
}
