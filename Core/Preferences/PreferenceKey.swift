//
//  PreferenceKey.swift
//
//
//  Created by Mohamed Afifi on 2021-12-17.
//

import Foundation

#if DEBUG
    private actor KeyRegistry {
        static let shared = KeyRegistry()
        private var registeredKeys = Set<String>()
        
        func register(key: String) {
            if registeredKeys.contains(key) {
                fatalError("PersistenceKey '\(key)' is registered multiple times")
            }
            registeredKeys.insert(key)
        }
    }
#endif

public final class PreferenceKey<Type>: @unchecked Sendable {
    // MARK: Lifecycle

    public init(key: String, defaultValue: Type) {
        self.key = key
        self.defaultValue = defaultValue

        #if DEBUG
            Task {
                await KeyRegistry.shared.register(key: key)
            }
        #endif
    }

    init(_ key: String, _ defaultValue: Type) {
        self.key = key
        self.defaultValue = defaultValue
    }

    // MARK: Public

    public let key: String
    public let defaultValue: Type
}
