//
//  PreferenceTransformer.swift
//
//
//  Created by Mohamed Afifi on 2022-09-10.
//

public struct PreferenceTransformer<Raw, T>: Sendable {
    // MARK: Lifecycle

    public init(
        rawToValue: @escaping @Sendable (Raw) -> T,
        valueToRaw: @escaping @Sendable (T) -> Raw
    ) {
        self.rawToValue = rawToValue
        self.valueToRaw = valueToRaw
    }

    // MARK: Public

    public let rawToValue: @Sendable (Raw) -> T
    public let valueToRaw: @Sendable (T) -> Raw
}

extension PreferenceTransformer where T: RawRepresentable, T.RawValue == Raw {
    public static func rawRepresentable(defaultValue: @escaping @autoclosure @Sendable () -> T) -> Self {
        PreferenceTransformer(
            rawToValue: { T(rawValue: $0) ?? defaultValue() },
            valueToRaw: { $0.rawValue }
        )
    }
}

public func optionalTransfomer<Raw, T>(of transformer: PreferenceTransformer<Raw, T>) -> PreferenceTransformer<Raw?, T?> {
    PreferenceTransformer(
        rawToValue: { $0.map { transformer.rawToValue($0) } },
        valueToRaw: { $0.map { transformer.valueToRaw($0) } }
    )
}

// MARK: - Standard Transformers

extension PreferenceTransformer where Raw == String, T == String {
    public static let string: Self = PreferenceTransformer(
        rawToValue: { $0 },
        valueToRaw: { $0 }
    )
}

extension PreferenceTransformer where Raw == String, T == String? {
    public static let optionalString: Self = PreferenceTransformer(
        rawToValue: { $0.isEmpty ? nil : $0 },
        valueToRaw: { $0 ?? "" }
    )
}

extension PreferenceTransformer where Raw == String, T == Int {
    public static let int: Self = PreferenceTransformer(
        rawToValue: { Int($0) ?? 0 },
        valueToRaw: { String($0) }
    )
}

extension PreferenceTransformer where Raw == String, T == Double {
    public static let double: Self = PreferenceTransformer(
        rawToValue: { Double($0) ?? 0.0 },
        valueToRaw: { String($0) }
    )
}

extension PreferenceTransformer where Raw == String, T == Bool {
    public static let bool: Self = PreferenceTransformer(
        rawToValue: { $0.lowercased() == "true" },
        valueToRaw: { $0 ? "true" : "false" }
    )
}

extension PreferenceTransformer where Raw == String, T == [Int] {
    public static let intArray: Self = PreferenceTransformer(
        rawToValue: { string in
            guard !string.isEmpty else { return [] }
            return string.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        },
        valueToRaw: { array in
            array.map(String.init).joined(separator: ",")
        }
    )
}

extension PreferenceTransformer where Raw == String, T == TimeInterval {
    public static let timeInterval: Self = PreferenceTransformer(
        rawToValue: { Double($0) ?? 0.0 },
        valueToRaw: { String($0) }
    )
}

extension PreferenceTransformer where Raw == String, T == TimeInterval? {
    public static let optionalTimeInterval: Self = PreferenceTransformer(
        rawToValue: { string in
            guard !string.isEmpty else { return nil }
            return Double(string)
        },
        valueToRaw: { interval in
            guard let interval = interval else { return "" }
            return String(interval)
        }
    )
}

extension PreferenceTransformer where Raw == String, T == Int? {
    public static let optionalInt: Self = PreferenceTransformer(
        rawToValue: { string in
            guard !string.isEmpty else { return nil }
            return Int(string)
        },
        valueToRaw: { int in
            guard let int = int else { return "" }
            return String(int)
        }
    )
}
