import Primitives

/// Generates static StringIdentifier members from declared member names.
///
/// By default, each generated raw value exactly matches its member name.
/// `rawValueCasing` can transform the member spelling into a different
/// serialized representation.
///
///     public extension ExampleIdentifier {
///         #StringIdentifiers(
///             "firstValue",
///             "secondValue",
///             rawValueCasing: .snake
///         )
///     }
///
/// This generates members whose raw values are `first_value` and
/// `second_value` respectively.
@freestanding(declaration, names: arbitrary)
public macro StringIdentifiers(
    _ names: String...,
    rawValueCasing: Casing? = nil
) = #externalMacro(
    module: "MacrosPlugin",
    type: "StringIdentifiersMacro"
)
