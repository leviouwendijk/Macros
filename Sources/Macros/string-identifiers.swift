import Primitives

/// Synthesizes get-only StringIdentifier values for declared static members.
///
///     @StringIdentifiers(casing: .snake)
///     public extension ExampleIdentifier {
///         static var firstValue: Self
///         static var secondValue: Self
///     }
///
/// The generated getters return values whose raw strings are `first_value`
/// and `second_value` respectively.
///
/// When `casing` is omitted, the member spelling is used as the raw value.
@attached(memberAttribute)
public macro StringIdentifiers(
    casing: Casing? = nil
) = #externalMacro(
    module: "MacrosPlugin",
    type: "StringIdentifiersMacro"
)

/// Implementation detail used by `@StringIdentifiers` to synthesize each
/// declared member's getter.
@attached(accessor)
public macro _StringIdentifier(
    casing: Casing? = nil
) = #externalMacro(
    module: "MacrosPlugin",
    type: "StringIdentifierMemberMacro"
)
