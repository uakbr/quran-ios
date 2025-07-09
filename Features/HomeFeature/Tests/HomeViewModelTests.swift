//
//  HomeViewModelTests.swift
//
//
//  Created by Mohamed Afifi on 2025-01-08.
//

import AnnotationsService
import AsyncUtilitiesForTesting
import Combine
import Foundation
import QuranAnnotations
import QuranKit
import QuranText
import QuranTextKit
import ReadingService
import XCTest
@testable import HomeFeature

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var mockLastPageService: MockLastPageService!
    private var mockTextRetriever: MockQuranTextDataService!
    private var navigationPages: [Page] = []
    private var navigationSuras: [Sura] = []
    private var navigationQuarters: [Quarter] = []
    private var sut: HomeViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockLastPageService = MockLastPageService()
        mockTextRetriever = MockQuranTextDataService()
        navigationPages = []
        navigationSuras = []
        navigationQuarters = []
        
        sut = HomeViewModel(
            lastPageService: mockLastPageService,
            textRetriever: mockTextRetriever,
            navigateToPage: { [weak self] page in 
                self?.navigationPages.append(page)
            },
            navigateToSura: { [weak self] sura in 
                self?.navigationSuras.append(sura)
            },
            navigateToQuarter: { [weak self] quarter in 
                self?.navigationQuarters.append(quarter)
            }
        )
    }
    
    func testInitialState() {
        XCTAssertEqual(sut.type, .suras)
        XCTAssertEqual(sut.surahSortOrder, .ascending)
        XCTAssertTrue(sut.suras.isEmpty)
        XCTAssertTrue(sut.quarters.isEmpty)
        XCTAssertTrue(sut.lastPages.isEmpty)
    }
    
    func testNavigateToPage() {
        let page = Page(pageNumber: 42)!
        
        sut.navigateTo(page)
        
        XCTAssertEqual(navigationPages, [page])
        XCTAssertTrue(navigationSuras.isEmpty)
        XCTAssertTrue(navigationQuarters.isEmpty)
    }
    
    func testNavigateToSura() {
        let sura = Sura(quran: Quran.hafsMadani1, suraNumber: 2)!
        
        sut.navigateTo(sura)
        
        XCTAssertEqual(navigationSuras, [sura])
        XCTAssertTrue(navigationPages.isEmpty)
        XCTAssertTrue(navigationQuarters.isEmpty)
    }
    
    func testNavigateToQuarter() {
        let quarter = Quarter(juz: 1, quarter: 2)!
        let quarterItem = QuarterItem(quarter: quarter, ayahText: "Test ayah")
        
        sut.navigateTo(quarterItem)
        
        XCTAssertEqual(navigationQuarters, [quarter])
        XCTAssertTrue(navigationPages.isEmpty)
        XCTAssertTrue(navigationSuras.isEmpty)
    }
    
    func testToggleSurahSortOrder() {
        XCTAssertEqual(sut.surahSortOrder, .ascending)
        
        sut.toggleSurahSortOrder()
        XCTAssertEqual(sut.surahSortOrder, .descending)
        
        sut.toggleSurahSortOrder()
        XCTAssertEqual(sut.surahSortOrder, .ascending)
    }
    
    func testHomeViewTypeChange() {
        XCTAssertEqual(sut.type, .suras)
        
        sut.type = .juzs
        XCTAssertEqual(sut.type, .juzs)
        
        sut.type = .suras
        XCTAssertEqual(sut.type, .suras)
    }
    
    func testStartLoadsData() async {
        let testLastPages = [LastPage(page: 42, creationDate: Date())]
        let testSuras = [Sura(quran: Quran.hafsMadani1, suraNumber: 1)!]
        let testQuarters = [QuarterItem(quarter: Quarter(juz: 1, quarter: 1)!, ayahText: "Test")]
        
        mockLastPageService.lastPagesToReturn = testLastPages
        mockTextRetriever.surasToReturn = testSuras
        mockTextRetriever.quartersToReturn = testQuarters
        
        await sut.start()
        
        XCTAssertEqual(sut.lastPages, testLastPages)
        XCTAssertEqual(sut.suras, testSuras)
        XCTAssertEqual(sut.quarters, testQuarters)
    }
    
    func testStartHandlesErrors() async {
        let testError = TestError.mockError
        mockLastPageService.errorToThrow = testError
        
        // Should not crash even if one service fails
        await sut.start()
        
        // Other services should still be called
        XCTAssertTrue(mockTextRetriever.getSurasCalled)
        XCTAssertTrue(mockTextRetriever.getQuartersCalled)
    }
}

// MARK: - Mock Classes

@MainActor
private class MockLastPageService: LastPageService {
    var lastPagesToReturn: [LastPage] = []
    var errorToThrow: Error?
    var getLastPagesCalled = false
    
    override func getLastPages() async throws -> [LastPage] {
        getLastPagesCalled = true
        if let error = errorToThrow {
            throw error
        }
        return lastPagesToReturn
    }
}

@MainActor
private class MockQuranTextDataService: QuranTextDataService {
    var surasToReturn: [Sura] = []
    var quartersToReturn: [QuarterItem] = []
    var errorToThrow: Error?
    var getSurasCalled = false
    var getQuartersCalled = false
    
    override func getSuras() async throws -> [Sura] {
        getSurasCalled = true
        if let error = errorToThrow {
            throw error
        }
        return surasToReturn
    }
    
    override func getQuarters() async throws -> [QuarterItem] {
        getQuartersCalled = true
        if let error = errorToThrow {
            throw error
        }
        return quartersToReturn
    }
}

private enum TestError: Error {
    case mockError
} 