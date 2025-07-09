//
//  BookmarksViewModelTests.swift
//
//
//  Created by Mohamed Afifi on 2025-01-08.
//

import Analytics
import AnnotationsService
import AsyncUtilitiesForTesting
import Combine
import QuranAnnotations
import QuranKit
import ReadingService
import SwiftUI
import XCTest
@testable import BookmarksFeature

@MainActor
final class BookmarksViewModelTests: XCTestCase {
    private var mockAnalytics: MockAnalyticsLibrary!
    private var mockService: MockPageBookmarkService!
    private var navigatedPages: [Page] = []
    private var sut: BookmarksViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockAnalytics = MockAnalyticsLibrary()
        mockService = MockPageBookmarkService()
        navigatedPages = []
        
        sut = BookmarksViewModel(
            analytics: mockAnalytics,
            service: mockService,
            navigateTo: { [weak self] page in
                self?.navigatedPages.append(page)
            }
        )
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.editMode, .inactive)
        XCTAssertNil(sut.error)
        XCTAssertTrue(sut.bookmarks.isEmpty)
    }
    
    func testNavigateToBookmark() {
        let page = Page(pageNumber: 42)!
        let bookmark = PageBookmark(page: page, creationDate: Date())
        
        sut.navigateTo(bookmark)
        
        XCTAssertEqual(navigatedPages, [page])
        XCTAssertTrue(mockAnalytics.openingQuranCalled)
    }
    
    func testDeleteBookmarkSuccess() async {
        let page = Page(pageNumber: 42)!
        let bookmark = PageBookmark(page: page, creationDate: Date())
        mockService.shouldSucceed = true
        
        await sut.deleteItem(bookmark)
        
        XCTAssertTrue(mockService.removePageBookmarkCalled)
        XCTAssertEqual(mockService.removedPages, [page])
        XCTAssertTrue(mockAnalytics.removeBookmarkCalled)
        XCTAssertNil(sut.error)
    }
    
    func testDeleteBookmarkError() async {
        let page = Page(pageNumber: 42)!
        let bookmark = PageBookmark(page: page, creationDate: Date())
        mockService.shouldSucceed = false
        mockService.errorToThrow = TestError.deletionFailed
        
        await sut.deleteItem(bookmark)
        
        XCTAssertTrue(mockService.removePageBookmarkCalled)
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(mockAnalytics.removeBookmarkCalled)
    }
    
    func testEditModeToggling() {
        XCTAssertEqual(sut.editMode, .inactive)
        
        sut.editMode = .active
        XCTAssertEqual(sut.editMode, .active)
        
        sut.editMode = .inactive
        XCTAssertEqual(sut.editMode, .inactive)
    }
    
    func testStartLoadsBookmarks() async {
        let testBookmarks = [
            PageBookmark(page: Page(pageNumber: 1)!, creationDate: Date().addingTimeInterval(-100)),
            PageBookmark(page: Page(pageNumber: 2)!, creationDate: Date())
        ]
        mockService.bookmarksToReturn = testBookmarks
        
        await sut.start()
        
        // Wait for the async sequence to update
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Should be sorted by creation date (newest first)
        XCTAssertEqual(sut.bookmarks.count, 2)
        XCTAssertEqual(sut.bookmarks.first?.page.pageNumber, 2)
        XCTAssertEqual(sut.bookmarks.last?.page.pageNumber, 1)
    }
}

// MARK: - Mock Classes

private class MockAnalyticsLibrary: AnalyticsLibrary {
    var openingQuranCalled = false
    var removeBookmarkCalled = false
    
    func openingQuran(from source: OpenQuranSource) {
        openingQuranCalled = true
    }
    
    func removeBookmarkPage(_ page: Page) {
        removeBookmarkCalled = true
    }
    
    // Implement other required methods with empty implementations
    func cloudkitLoggedIn(_ status: CloudKitStatus) {}
    func addBookmarkPage(_ page: Page) {}
    func wordTranslationPresented() {}
    func presentAyahMenu(startingPage: Page) {}
}

@MainActor
private class MockPageBookmarkService: PageBookmarkService {
    var bookmarksToReturn: [PageBookmark] = []
    var shouldSucceed = true
    var errorToThrow: Error?
    var removePageBookmarkCalled = false
    var removedPages: [Page] = []
    
    override func pageBookmarks(quran: Quran) -> AnyPublisher<[PageBookmark], Never> {
        Just(bookmarksToReturn)
            .eraseToAnyPublisher()
    }
    
    override func removePageBookmark(_ page: Page) async throws {
        removePageBookmarkCalled = true
        removedPages.append(page)
        
        if !shouldSucceed, let error = errorToThrow {
            throw error
        }
    }
}

private enum TestError: Error {
    case deletionFailed
    case networkError
} 