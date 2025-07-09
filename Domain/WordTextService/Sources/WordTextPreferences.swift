//
//  WordTextPreferences.swift
//
//
//  Created by Mohamed Afifi on 2023-06-08.
//

import Preferences
import QuranText

public struct WordTextPreferences {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    public static let shared = WordTextPreferences()

    @TransformedPreference(key: Self.wordTextTypeKey, transformer: .rawRepresentable(defaultValue: Self.defaultWordTextType), defaultValue: Self.defaultWordTextType)
    public var wordTextType: WordTextType

    // MARK: Private

    private static let defaultWordTextType = WordTextType.translation
    private static let wordTextTypeKey = PreferenceKey<Int>(key: "wordTranslationType", transformer: .int)
}
