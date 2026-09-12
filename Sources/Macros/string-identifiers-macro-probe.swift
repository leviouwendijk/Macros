import Primitives

internal struct StringIdentifiersMacroProbe: StringIdentifier {
    let rawValue: String

    init(
        rawValue: String
    ) {
        self.rawValue = rawValue
    }
}

internal extension StringIdentifiersMacroProbe {
    #StringIdentifiers(
        "firstValue",
        "secondValue",
        rawValueCasing: .snake
    )
}

private let stringIdentifiersMacroProbeValues = [
    StringIdentifiersMacroProbe.firstValue.rawValue,
    StringIdentifiersMacroProbe.secondValue.rawValue,
]
