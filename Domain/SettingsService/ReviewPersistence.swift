//
//  ReviewPersistence.swift
//  Quran
//
//  Created by Mohamed Afifi on 2021-12-14.
//  Copyright © 2021 Quran.com. All rights reserved.
//

import Foundation
import Preferences

final class ReviewPersistence {
    // MARK: Lifecycle

    private init() {}

    // MARK: Public

    public static let shared = ReviewPersistence()

    // MARK: Internal

    @Preference(key: Self.appOpenedCounterKey, defaultValue: 0)
    var appOpenedCounter: Int

    @TransformedPreference(key: Self.appInstalledDateKey, transformer: Self.dateTransfomer, defaultValue: Date())
    var appInstalledDate: Date

    @TransformedPreference(key: Self.requestReviewDateKey, transformer: optionalTransfomer(of: Self.dateTransfomer), defaultValue: nil)
    var requestReviewDate: Date?

    // MARK: Private

    private static let appOpenedCounterKey = PreferenceKey<Int>(key: "appOpenedCounter", transformer: .int)
    private static let appInstalledDateKey = PreferenceKey<TimeInterval>(key: "appInstalledDate", transformer: .timeInterval)
    private static let requestReviewDateKey = PreferenceKey<TimeInterval?>(key: "requestReviewDate", transformer: .optionalTimeInterval)

    private static let dateTransfomer = PreferenceTransformer<TimeInterval, Date>(
        rawToValue: { Date(timeIntervalSince1970: $0) },
        valueToRaw: { $0.timeIntervalSince1970 }
    )
}
