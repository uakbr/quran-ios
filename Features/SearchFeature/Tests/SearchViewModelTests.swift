//
//  SearchViewModelTests.swift
//
//
//  Created by Mohamed Afifi on 2025-01-08.
//

import Analytics
import AsyncUtilitiesForTesting
import Combine
import QuranKit
import QuranText
import QuranTextKit
import ReadingService
import TranslationService
import XCTest
@testable import SearchFeature

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var mockAnalytics: MockAnalyticsLibrary!
    private var mockSearchService: MockCompositeSearcher!
    private var navigatedVerses: [AyahNumber] = []
    private var sut: SearchViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockAnalytics = MockAnalyticsLibrary()
        mockSearchService = MockCompositeSearcher()
        navigatedVerses = []
        
        sut = SearchViewModel(
            analytics: mockAnalytics,
            searchService: mockSearchService,
            navigateTo: { [weak self] verse in
                self?.navigatedVerses.append(verse)
            }
        )
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.uiState, .entry)
        XCTAssertEqual(sut.searchState, .searching)
        XCTAssertTrue(sut.searchTerm.isEmpty)
        XCTAssertTrue(sut.autocompletions.isEmpty)
        XCTAssertTrue(sut.recents.isEmpty)
        XCTAssertEqual(sut.keyboardState, .closed)
        XCTAssertNil(sut.error)
    }
    
    func testSearchForTerm() {
        let searchTerm = "Allah"
        
        sut.search(for: searchTerm)
        
        XCTAssertEqual(sut.searchTerm, searchTerm)
        XCTAssertEqual(sut.keyboardState, .closed)
        
        switch sut.uiState {
        case .search(let term):
            XCTAssertEqual(term, searchTerm)
        default:
            XCTFail("Expected search state")
        }
    }
    
    func testSearchForUserTypedTerm() {
        sut.searchTerm = "test query"
        
        sut.searchForUserTypedTerm()
        
        switch sut.uiState {
        case .search(let term):
            XCTAssertEqual(term, "test query")
        default:
            XCTFail("Expected search state")
        }
    }
    
    func testAutocomplete() {
        let term = "Al"
        
        sut.autocomplete(term)
        
        XCTAssertEqual(sut.searchTerm, term)
        XCTAssertEqual(sut.uiState, .entry)
    }
    
    func testSelectSearchResult() {
        let quran = Quran.hafsMadani1
        let verse = AyahNumber(quran: quran, sura: 2, ayah: 255)!
        let searchResult = SearchResult(ayah: verse, text: "Test result")
        
        sut.select(searchResult: searchResult, source: .quran)
        
        XCTAssertEqual(navigatedVerses, [verse])
        XCTAssertTrue(mockAnalytics.openingQuranCalled)
    }
    
    func testSelectSearchResultFromTranslation() {
        let quran = Quran.hafsMadani1
        let verse = AyahNumber(quran: quran, sura: 2, ayah: 255)!
        let searchResult = SearchResult(ayah: verse, text: "Test result")
        let translation = Translation.Test.translation1
        
        sut.select(searchResult: searchResult, source: .translation(translation))
        
        XCTAssertEqual(navigatedVerses, [verse])
        XCTAssertTrue(mockAnalytics.openingQuranCalled)
    }
    
    func testReset() {
        // Set up some state
        sut.search(for: "test")
        sut.autocompletions = ["test1", "test2"]
        
        sut.reset()
        
        XCTAssertEqual(sut.uiState, .entry)
        XCTAssertTrue(sut.searchTerm.isEmpty)
        XCTAssertTrue(sut.autocompletions.isEmpty)
    }
    
    func testStartLoadsInitialData() async {
        mockSearchService.recentTermsToReturn = ["recent1", "recent2"]
        
        await sut.start()
        
        // Should load recent searches
        XCTAssertFalse(sut.recents.isEmpty)
    }
    
    func testErrorHandling() async {
        let testError = TestError.searchFailed
        mockSearchService.errorToThrow = testError
        sut.search(for: "test")
        
        // Wait for async search to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        XCTAssertNotNil(sut.error)
    }
    
    func testKeyboardStateChanges() {
        XCTAssertEqual(sut.keyboardState, .closed)
        
        sut.keyboardState = .open
        XCTAssertEqual(sut.keyboardState, .open)
        
        sut.search(for: "test")
        XCTAssertEqual(sut.keyboardState, .closed)
    }
}

// MARK: - Mock Classes

private class MockAnalyticsLibrary: AnalyticsLibrary {
    var openingQuranCalled = false
    
    func openingQuran(from source: OpenQuranSource) {
        openingQuranCalled = true
    }
    
    // Implement other required methods with empty implementations
    func cloudkitLoggedIn(_ status: CloudKitStatus) {}
    func removeBookmarkPage(_ page: Page) {}
    func addBookmarkPage(_ page: Page) {}
    func wordTranslationPresented() {}
    func presentAyahMenu(startingPage: Page) {}
}

private class MockCompositeSearcher: CompositeSearcher {
    var recentTermsToReturn: [String] = []
    var searchResultsToReturn: [SearchResults] = []
    var errorToThrow: Error?
    
    override func autocomplete(term: String) async throws -> [String] {
        if let error = errorToThrow {
            throw error
        }
        return recentTermsToReturn.filter { $0.contains(term) }
    }
    
    override func search(for term: String) async throws -> [SearchResults] {
        if let error = errorToThrow {
            throw error
        }
        return searchResultsToReturn
    }
}

private enum TestError: Error {
    case searchFailed
    case networkError
}

// MARK: - Test Extensions

extension Translation {
    enum Test {
        static let translation1 = Translation(
            id: 1,
            displayName: "Test Translation",
            translator: "Test Translator",
            translatorForeign: nil,
            fileURL: URL(string: "file://test")!,
            fileName: "test.db",
            isDownloaded: true
        )
    }
} 