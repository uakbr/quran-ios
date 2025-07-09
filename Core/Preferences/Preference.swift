//
//  Preference.swift
//  
//
//  Created by Mohamed Afifi on 2023-06-03.
//

import Combine
import Foundation

@MainActor
@propertyWrapper
public struct Preference<T> {
    // MARK: Lifecycle

    public init(key: PreferenceKey<T>, defaultValue: @autoclosure @escaping @Sendable () -> T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    // MARK: Public

    public var wrappedValue: T {
        get {
            key.valueForKey() ?? defaultValue()
        }
        nonmutating set {
            key.setValue(newValue, forKey: key.key)
        }
    }
    
    public var projectedValue: AnyPublisher<T, Never> {
        key.notifications
            .map { _ in self.wrappedValue }
            .prepend(wrappedValue)
            .eraseToAnyPublisher()
    }

    // MARK: Private

    private let key: PreferenceKey<T>
    private let defaultValue: @Sendable () -> T
}

@MainActor
@propertyWrapper
public struct TransformedPreference<T, V> {
    // MARK: Lifecycle

    public init(
        key: PreferenceKey<T>,
        transformer: PreferenceTransformer<T, V>,
        defaultValue: @autoclosure @escaping @Sendable () -> V
    ) {
        self.preference = Preference(key: key, defaultValue: transformer.rawToValue(transformer.valueToRaw(defaultValue())))
        self.transformer = transformer
        self.defaultValue = defaultValue
    }

    // MARK: Public

    public var wrappedValue: V {
        get {
            transformer.rawToValue(preference.wrappedValue)
        }
        nonmutating set {
            preference.wrappedValue = transformer.valueToRaw(newValue)
        }
    }
    
    public var projectedValue: AnyPublisher<V, Never> {
        preference.projectedValue
            .map(transformer.rawToValue)
            .eraseToAnyPublisher()
    }

    // MARK: Private

    private let preference: Preference<T>
    private let transformer: PreferenceTransformer<T, V>
    private let defaultValue: @Sendable () -> V
}
