import Primitives

internal struct StringIdentifiersMacroProbe: StringIdentifier {
    let rawValue: String

    init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

@StringIdentifiers(casing: .snake)
internal extension StringIdentifiersMacroProbe {
    static var firstValue: Self
    static var secondValue: Self
}

private let stringIdentifiersMacroProbeValues = [
    StringIdentifiersMacroProbe.firstValue.rawValue,
    StringIdentifiersMacroProbe.secondValue.rawValue,
]

internal struct ExactStringIdentifiersMacroProbe: StringIdentifier {
    let rawValue: String

    init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

@StringIdentifiers
internal extension ExactStringIdentifiersMacroProbe {
    static var transport_transient: Self
    static var rate_limited: Self
}

private let exactStringIdentifiersMacroProbeValues = [
    ExactStringIdentifiersMacroProbe.transport_transient.rawValue,
    ExactStringIdentifiersMacroProbe.rate_limited.rawValue,
]
