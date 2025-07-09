//
//  NumberFormatter+Extension.swift
//  
//
//  Created by Mohamed Afifi on 2023-06-28.
//

import Foundation

extension NumberFormatter {
    private static let _arabicNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ar")
        return formatter
    }()
    
    @MainActor
    public static var arabicNumberFormatter: NumberFormatter {
        _arabicNumberFormatter
    }
    
    public func format(_ number: Int) -> String {
        string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

public extension Locale {
    func fixedLocaleNumbers() -> Locale {
        let latinSuffix = "@numbers=latn"
        if identifier.hasSuffix(latinSuffix) {
            let localId = identifier.replacingOccurrences(of: latinSuffix, with: "")
            return Locale(identifier: localId)
        } else {
            return self
        }
    }

    static var fixedCurrentLocaleNumbers: Locale {
        current.fixedLocaleNumbers()
    }
}
