//
//  SimpleCoreDataEntityUniquifierTests.swift
//
//
//  Created by Mohamed Afifi on 2023-05-28.
//

import CoreData
import CoreDataModel
import CoreDataPersistenceTestSupport
import SystemDependencies
import SystemDependenciesFake
import XCTest
@testable import CoreDataPersistence

class SimpleCoreDataEntityUniquifierTests: XCTestCase {
    var sut: SimpleCoreDataEntityUniquifier<MO_PageBookmark>!
    var transactions: [PersistentHistoryTransaction]!
    var context: NSManagedObjectContext!
    var stack: CoreDataStack!

    var existingEntity: MO_PageBookmark!
    var entity1: MO_PageBookmark!
    var entity2: MO_PageBookmark!
    var entity3: MO_PageBookmark!

    override func setUp() async throws {
        try await super.setUp()

        stack = try CoreDataStack.testingStack()
        uniquifier = SimpleCoreDataEntityUniquifier()
    }

    override func tearDown() {
        CoreDataStack.removePersistentFiles()
        sut = nil
        transactions = nil
        context = nil
        stack = nil
        super.tearDown()
    }

    func test_merge() throws {
        XCTAssertEqual([45, 45, 500], try context.allPageBookmarks().map(\.page))

        XCTAssertNoThrow(try sut.merge(transactions: transactions, using: context))

        XCTAssertEqual([45, 500], try stack.newBackgroundContext().allPageBookmarks().map(\.page))
    }
}
