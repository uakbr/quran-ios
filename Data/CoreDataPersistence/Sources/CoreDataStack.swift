//
//  CoreDataStack.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/1/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import CoreData
import Foundation
import Utilities
import VLogging

public enum CoreDataStackError: Error, LocalizedError {
    case persistentStoreDescriptionNotFound
    case persistentStoreLoadFailed(Error)
    case viewContextPinningFailed(Error)
    case modelNotFound(URL)
    
    public var errorDescription: String? {
        switch self {
        case .persistentStoreDescriptionNotFound:
            return "Failed to retrieve a persistent store description"
        case .persistentStoreLoadFailed(let error):
            return "Failed to load persistent store: \(error.localizedDescription)"
        case .viewContextPinningFailed(let error):
            return "Failed to pin viewContext to the current generation: \(error.localizedDescription)"
        case .modelNotFound(let url):
            return "Cannot find Core Data model at: \(url.path)"
        }
    }
}

/// Core Data stack setup including history processing.
public class CoreDataStack {
    // MARK: Lifecycle

    public init(name: String, modelUrl: URL, lazyUniquifiers: @escaping () -> [CoreDataEntityUniquifier]) throws {
        self.name = name
        self.modelUrl = modelUrl
        self.lazyUniquifiers = lazyUniquifiers
        
        // Initialize the persistent container and validate it's working
        _ = try initializePersistentContainer()
    }

    // MARK: Public

    public var viewContext: NSManagedObjectContext {
        do {
            return try persistentContainer.viewContext
        } catch {
            logger.error("Failed to access viewContext: \(error)")
            // Return a temporary context to prevent crashes, but log the error
            return NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        }
    }

    public class func removePersistentFiles() {
        let dataDirectory = NSPersistentContainer.defaultDirectoryURL()
        FileManager.default.removeDirectoryContents(at: dataDirectory)
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        let container: NSPersistentContainer
        do {
            container = try persistentContainer
        } catch {
            logger.error("Failed to access persistent container: \(error)")
            // Return a temporary context to prevent crashes
            return NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        }
        
        let context = container.newBackgroundContext()
        context.transactionAuthor = appTransactionAuthorName
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: Internal

    /// A persistent container that can load cloud-backed and non-cloud stores.
    private var _persistentContainer: NSPersistentContainer?
    private var persistentContainer: NSPersistentContainer {
        get throws {
            if let container = _persistentContainer {
                return container
            }
            let container = try initializePersistentContainer()
            _persistentContainer = container
            return container
        }
    }
    
    private func initializePersistentContainer() throws -> NSPersistentContainer {
        let container = try newPersistenceContainer()

        // Enable history tracking and remote notifications
        guard let description = container.persistentStoreDescriptions.first else {
            logger.error("Failed to retrieve a persistent store description")
            throw CoreDataStackError.persistentStoreDescriptionNotFound
        }
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        var loadError: Error?
        container.loadPersistentStores(completionHandler: { _, error in
            if let error = error {
                loadError = error
            }
        })
        
        if let error = loadError {
            logger.error("Failed to load persistent store: \(error)")
            throw CoreDataStackError.persistentStoreLoadFailed(error)
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = appTransactionAuthorName

        // Pin the viewContext to the current generation token and set it to keep itself up to date with local changes.
        container.viewContext.automaticallyMergesChangesFromParent = true
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            logger.error("Failed to pin viewContext to the current generation: \(error)")
            throw CoreDataStackError.viewContextPinningFailed(error)
        }

        // Observe Core Data remote change notifications.
        NotificationCenter.default.addObserver(
            self, selector: #selector(Self.storeRemoteChange(_:)),
            name: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator
        )

        return container
    }

    // MARK: Private

    private let appTransactionAuthorName = "app"

    private let name: String
    private let modelUrl: URL

    private let lazyUniquifiers: () -> [CoreDataEntityUniquifier]
    private lazy var uniquifiers: [CoreDataEntityUniquifier] = lazyUniquifiers()

    private lazy var historyProcessor: CoreDataPersistentHistoryProcessor = CoreDataPersistentHistoryProcessor(name: name, uniquifiers: uniquifiers)

    /// An operation queue for handling history processing tasks: watching changes, deduplicating entities, and triggering UI updates if needed.
    private lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    private func newPersistenceContainer() throws -> NSPersistentContainer {
        guard let model = NSManagedObjectModel(contentsOf: modelUrl) else {
            logger.error("Cannot find Core Data model at: \(modelUrl.path)")
            throw CoreDataStackError.modelNotFound(modelUrl)
        }

        // Create a container that can load CloudKit-backed stores
        return NSPersistentCloudKitContainer(name: name, managedObjectModel: model)
    }

    /// Handle remote store change notifications (.NSPersistentStoreRemoteChange).
    @objc
    private func storeRemoteChange(_ notification: Notification) {
        logger.info("Merging changes from the other persistent store coordinator.")

        // Process persistent history to merge changes from other coordinators.
        historyQueue.addOperation {
            do {
                let taskContext = self.newBackgroundContext()
                taskContext.performAndWait {
                    self.historyProcessor.processNewHistory(using: taskContext)
                }
            } catch {
                logger.error("Failed to process remote store changes: \(error)")
            }
        }
    }
}

extension NSManagedObjectContext: @retroactive @unchecked Sendable {}
