import Primitives

/// Builds a nested API surface from ordinary nested Swift declarations.
///
/// A root:
///
///     @API(.root)
///     public final class Client {
///         ...
///     }
///
/// A namespace:
///
///     @API(.namespace)
///     public struct Users {
///         ...
///     }
///
/// When `property` is omitted, the namespace accessor is inferred from
/// the namespace type name using the selected `casing`:
///
///     @API(.namespace)
///     public struct Users {
///         ...
///     }
///
/// This produces:
///
///     root.users
///
/// Casing can be changed without explicitly supplying property words:
///
///     @API(
///         .namespace,
///         casing: .snake
///     )
///     public struct HTTPHeaders {
///         ...
///     }
///
/// This produces:
///
///     root.http_headers
///
/// For names whose semantic word boundaries or property vocabulary should
/// be explicit, provide the property words directly:
///
///     @API(
///         .namespace,
///         property: "http", "headers"
///     )
///     public struct HTTPHeaders {
///         ...
///     }
///
/// This produces:
///
///     root.httpHeaders
///
/// Explicit property words can be combined with any supported casing:
///
///     @API(
///         .namespace,
///         property: "http", "headers",
///         casing: .snake
///     )
///     public struct HTTPHeaders {
///         ...
///     }
///
/// This produces:
///
///     root.http_headers
///
/// By default, generated properties must be ordinary Swift identifiers.
/// Options can opt into escaped or raw identifiers:
///
///     @API(
///         .namespace,
///         property: "private",
///         options: .reservedKeywords
///     )
///     public struct Private {
///         ...
///     }
///
/// This produces:
///
///     root.`private`
///
/// Raw identifiers allow casing styles whose rendered values require
/// backtick-delimited Swift identifiers:
///
///     @API(
///         .namespace,
///         property: "http", "headers",
///         casing: .dot,
///         options: .rawIdentifiers
///     )
///     public struct HTTPHeaders {
///         ...
///     }
///
/// This produces:
///
///     root.`http.headers`
///
/// Use `.lenient` to permit any property spelling that `CasedProperty`
/// can represent as an ordinary, escaped, or raw Swift identifier:
///
///     @API(
///         .namespace,
///         casing: .kebab,
///         options: .lenient
///     )
///     public struct HTTPHeaders {
///         ...
///     }
///
/// This produces:
///
///     root.`http-headers`
///
/// Invalid property identifiers are rejected during macro expansion.
@attached(member, names: arbitrary)
public macro API(
    _ role: APIRole,
    property: String...,
    casing: Casing = .camel,
    options: CasedProperty.Options = []
) = #externalMacro(
    module: "MacrosPlugin",
    type: "APIMacro"
)
