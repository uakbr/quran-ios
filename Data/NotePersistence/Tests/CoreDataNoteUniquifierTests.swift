//
//  CoreDataNoteUniquifierTests.swift
//
//
//  Created by Mohamed Afifi on 2023-06-01.
//

import CoreData
import CoreDataModel
import CoreDataPersistence
import CoreDataPersistenceTestSupport
import NotePersistence
import SystemDependenciesFake
import XCTest

class CoreDataNoteUniquifierTests: XCTestCase {
    // MARK: Internal

    var sut: CoreDataNoteUniquifier!
    var context: NSManagedObjectContext!
    var stack: CoreDataStack!

    var verse1: MO_Verse!
    var verse2: MO_Verse!
    var verse3: MO_Verse!
    var verse4: MO_Verse!

    var note1: MO_Note!
    var note2: MO_Note!
    var note3: MO_Note!

    override func setUp() async throws {
        try await super.setUp()

        stack = try CoreDataStack.testingStack()
        uniquifier = CoreDataNoteUniquifier()
    }

    override func tearDown() {
        CoreDataStack.removePersistentFiles()
        sut = nil
        context = nil
        stack = nil
        super.tearDown()
    }

    func test_merge_shouldRemoveNotesWithNoVerses() throws {
        // Given
        try setUpNotesWithNoVerses()

        let insertedChange = PersistentHistoryChangeFake(object: note3, changeType: .insert)
        let transaction = PersistentHistoryTransactionFake(historyChanges: [insertedChange])

        // When
        XCTAssertNoThrow(try sut.merge(transactions: [transaction], using: context))

        // Then
        let notes = try context.allNotes()
        XCTAssertEqual(notes.map(\.note), ["Note 3", "Note 2"])
    }

    func test_merge_allNotesHaveVerses() throws {
        // Given
        try setUpAllNotesWithVerses()

        let insertedChange = PersistentHistoryChangeFake(object: note3, changeType: .insert)
        let transaction = PersistentHistoryTransactionFake(historyChanges: [insertedChange])

        // When
        XCTAssertNoThrow(try sut.merge(transactions: [transaction], using: context))

        // Then
        let notes = try context.allNotes()
        XCTAssertEqual(notes.map(\.note), ["Note 3", "Note 2", "Note 1"])
    }

    func test_merge_noRelatedNoteChange() throws {
        // Given
        try setUpAllNotesWithVerses()

        // When
        XCTAssertNoThrow(try sut.merge(transactions: [], using: context))

        // Then
        let notes = try context.allNotes()
        XCTAssertEqual(notes.map(\.note), ["Note 3", "Note 2", "Note 1"])
    }

    // MARK: Private

    // MARK: - Helpers

    private func setUpNotesWithNoVerses() throws {
        note1.addToVerses(verse1)
        note2.addToVerses(verse2)
        note3.addToVerses(verse3)
        note3.addToVerses(verse1)
        try context.save()
    }

    private func setUpAllNotesWithVerses() throws {
        note1.addToVerses(verse1)
        note1.addToVerses(verse4)
        note2.addToVerses(verse2)
        note3.addToVerses(verse3)
        note3.addToVerses(verse1)
        try context.save()
    }
}
