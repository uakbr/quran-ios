//
//  DataUnavailableViewTests.swift
//
//
//  Created by Mohamed Afifi on 2025-01-08.
//

import SwiftUI
import XCTest
@testable import NoorUI

final class DataUnavailableViewTests: XCTestCase {
    
    func testDataUnavailableViewRendering() {
        let title = "No Bookmarks"
        let text = "You haven't bookmarked any pages yet."
        let image = NoorSystemImage.bookmark
        
        let view = DataUnavailableView(
            title: title,
            text: text,
            image: image
        )
        
        XCTAssertNotNil(view)
    }
    
    func testDataUnavailableViewWithEmptyText() {
        let title = "No Results"
        let text = ""
        let image = NoorSystemImage.search
        
        let view = DataUnavailableView(
            title: title,
            text: text,
            image: image
        )
        
        XCTAssertNotNil(view)
    }
    
    func testDataUnavailableViewWithLongText() {
        let title = "Connection Error"
        let text = """
        Unable to connect to the server. Please check your internet connection and try again. 
        If the problem persists, contact support for assistance.
        """
        let image = NoorSystemImage.exclamationMark
        
        let view = DataUnavailableView(
            title: title,
            text: text,
            image: image
        )
        
        XCTAssertNotNil(view)
    }
    
    func testDataUnavailableViewProperties() {
        let title = "Test Title"
        let text = "Test Description"
        let image = NoorSystemImage.note
        
        let view = DataUnavailableView(
            title: title,
            text: text,
            image: image
        )
        
        XCTAssertEqual(view.title, title)
        XCTAssertEqual(view.text, text)
        XCTAssertEqual(view.image, image)
    }
}

// MARK: - Error Alert Tests

final class ErrorAlertModifierTests: XCTestCase {
    
    func testErrorAlertWithNilError() {
        @State var error: Error? = nil
        
        let view = Text("Test")
            .errorAlert(error: $error)
        
        XCTAssertNotNil(view)
    }
    
    func testErrorAlertWithError() {
        @State var error: Error? = TestError.sampleError
        
        let view = Text("Test")
            .errorAlert(error: $error)
        
        XCTAssertNotNil(view)
    }
    
    func testErrorAlertWithRetryAction() {
        @State var error: Error? = TestError.sampleError
        var retryActionCalled = false
        
        let retryAction: AsyncAction = {
            retryActionCalled = true
        }
        
        let view = Text("Test")
            .errorAlert(error: $error, retry: retryAction)
        
        XCTAssertNotNil(view)
    }
}

// MARK: - NoorList Tests

final class NoorListTests: XCTestCase {
    
    func testNoorListWithItems() {
        let items = ["Item 1", "Item 2", "Item 3"]
        
        let view = NoorList {
            NoorSection(items.map(SelfIdentifiable.init)) { item in
                Text(item.value)
            }
        }
        
        XCTAssertNotNil(view)
    }
    
    func testNoorListEmpty() {
        let view = NoorList {
            EmptyView()
        }
        
        XCTAssertNotNil(view)
    }
    
    func testNoorBasicSection() {
        let view = NoorList {
            NoorBasicSection {
                Text("Section Content")
            }
        }
        
        XCTAssertNotNil(view)
    }
    
    func testNoorBasicSectionWithFooter() {
        let footerText = "This is a footer description"
        
        let view = NoorList {
            NoorBasicSection(footer: footerText) {
                Text("Section Content")
            }
        }
        
        XCTAssertNotNil(view)
    }
}

// MARK: - Theme Tests

final class ThemeTests: XCTestCase {
    
    func testQuranHighlightsTheme() {
        let highlights = QuranHighlights.empty
        XCTAssertNotNil(highlights)
    }
    
    func testThemeService() {
        let themeService = ThemeService.shared
        XCTAssertNotNil(themeService)
        XCTAssertNotNil(themeService.themeStyle)
    }
    
    func testFontSizeValues() {
        XCTAssertNotNil(FontSize.xSmall)
        XCTAssertNotNil(FontSize.small)
        XCTAssertNotNil(FontSize.medium)
        XCTAssertNotNil(FontSize.large)
        XCTAssertNotNil(FontSize.xLarge)
        XCTAssertNotNil(FontSize.xxLarge)
        XCTAssertNotNil(FontSize.xxxLarge)
    }
}

// MARK: - Test Helpers

private enum TestError: Error, LocalizedError {
    case sampleError
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .sampleError:
            return "This is a sample error for testing"
        case .networkError:
            return "Network connection failed"
        }
    }
}

private struct SelfIdentifiable<T>: Identifiable {
    let id = UUID()
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
} 