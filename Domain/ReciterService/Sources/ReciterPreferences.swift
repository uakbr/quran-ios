//
//  ReciterPreferences.swift
//
//
//  Created by Mohamed Afifi on 2023-06-04.
//

import OrderedCollections
import Preferences

@MainActor
public class ReciterPreferences {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    public static let shared = ReciterPreferences()

    @Preference(key: Self.lastSelectedReciterIdKey, defaultValue: 41)
    public var lastSelectedReciterId: Int

    @TransformedPreference(key: Self.recentReciterIdsKey, transformer: Self.recentReciterIdsTransfomer, defaultValue: OrderedSet<Int>())
    public var recentReciterIds: OrderedSet<Int>

    public func reset() {
        Self.lastSelectedReciterIdKey.removeValueForKey()
        Self.recentReciterIdsKey.removeValueForKey()
    }

    // MARK: Private

    private static let lastSelectedReciterIdKey = PreferenceKey<Int>(key: "LastSelectedQariId", transformer: .int)
    private static let recentReciterIdsKey = PreferenceKey<[Int]>(key: "recentRecitersIdsKey", transformer: .intArray)
    private static let recentReciterIdsTransfomer = PreferenceTransformer<[Int], OrderedSet<Int>>(
        rawToValue: { OrderedSet($0) },
        valueToRaw: { Array($0) }
    )
}
