//
//  PreferenceKey.swift
//  
//
//  Created by Mohamed Afifi on 2023-06-03.
//

import Combine
import Foundation

public actor KeyRegistry {
    public static let shared = KeyRegistry()
    
    private var keys: [String: Any] = [:]
    
    private init() {}
    
    public func register<T>(_ key: PreferenceKey<T>) {
        keys[key.key] = key
    }
    
    public func key<T>(for keyString: String, ofType type: T.Type) -> PreferenceKey<T>? {
        keys[keyString] as? PreferenceKey<T>
    }
}

@MainActor
public final class PreferenceKey<T>: Sendable {
    // MARK: Lifecycle

    public init(key: String, transformer: PreferenceTransformer<String, T>) {
        self.key = key
        self.transformer = transformer
        self.notifications = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .map { _ in () }
            .eraseToAnyPublisher()
        
        // Register this key
        Task {
            await KeyRegistry.shared.register(self)
        }
    }

    // MARK: Public

    public let key: String
    public let notifications: AnyPublisher<Void, Never>
    
    public func valueForKey() -> T? {
        guard let stringValue = UserDefaults.standard.string(forKey: key) else {
            return nil
        }
        return transformer.rawToValue(stringValue)
    }
    
    public func setValue(_ value: T, forKey key: String) {
        let stringValue = transformer.valueToRaw(value)
        UserDefaults.standard.set(stringValue, forKey: key)
    }
    
    public func removeValueForKey() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Private

    private let transformer: PreferenceTransformer<String, T>
}
