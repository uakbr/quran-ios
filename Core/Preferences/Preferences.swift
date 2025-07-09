//
//  Preferences.swift
//  
//
//  Created by Mohamed Afifi on 2023-06-03.
//

import Foundation

@MainActor
public final class Preferences: Sendable {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    public static let shared = Preferences()
    
    public func valueForKey<T>(_ key: String, type: T.Type) -> T? where T: Codable {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    public func setValue<T>(_ value: T, forKey key: String) where T: Codable {
        let data = try? JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: key)
    }
    
    public func removeValueForKey(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
