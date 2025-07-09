//
//  Container.swift
//  QuranEngineApp
//
//  Created by Mohamed Afifi on 2023-06-24.
//

import Analytics
import AppDependencies
import AuthenticationClient
import BatchDownloader
import CoreDataModel
import CoreDataPersistence
import Foundation
import LastPagePersistence
import NotePersistence
import PageBookmarkPersistence
import ReadingService
import UIKit
import VLogging

/// Hosts singleton dependencies
class Container: AppDependencies {
    // MARK: Lifecycle

    private init() {}

    // MARK: Internal

    static let shared = Container()

    let remoteResources: ReadingRemoteResources? = nil
    private(set) lazy var readingResources = ReadingResourcesService(downloader: downloadManager, remoteResources: remoteResources)

    let analytics: AnalyticsLibrary = LoggingAnalyticsLibrary()

    private(set) lazy var lastPagePersistence: LastPagePersistence = CoreDataLastPagePersistence(stack: coreDataStack)
    private(set) lazy var pageBookmarkPersistence: PageBookmarkPersistence = CoreDataPageBookmarkPersistence(stack: coreDataStack)
    private(set) lazy var notePersistence: NotePersistence = CoreDataNotePersistence(stack: coreDataStack)
    private(set) lazy var authenticationClient: (any AuthenticationClient)? = {
        guard let configurations = Constant.QuranOAuthAppConfigurations else {
            return nil
        }
        let client = AuthenticationClientImpl(configurations: configurations)
        return client
    }()

    private(set) lazy var downloadManager: DownloadManager = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "DownloadsBackgroundIdentifier")
        configuration.timeoutIntervalForRequest = 60 * 5 // 5 minutes
        return DownloadManager(
            maxSimultaneousDownloads: 600,
            configuration: configuration,
            downloadsURL: Constant.databasesURL.appendingPathComponent("downloads.db", isDirectory: false)
        )
    }()

    var databasesURL: URL { Constant.databasesURL }
    var wordsDatabase: URL { Constant.wordsDatabase }
    var filesAppHost: URL { Constant.filesAppHost }
    var appHost: URL { Constant.appHost }
    var databasesDirectory: URL { Constant.databasesURL }
    var logsDirectory: URL { FileManager.documentsURL.appendingPathComponent("logs") }

    var supportsCloudKit: Bool { false }

    // MARK: Private

    private var _coreDataStack: CoreDataStack?
    private var coreDataStack: CoreDataStack {
        if let stack = _coreDataStack {
            return stack
        }
        
        do {
            let stack = try CoreDataStack(name: "Quran", modelUrl: CoreDataModelResources.quranModel) {
                let lastPage = CoreDataLastPageUniquifier()
                let pageBookmark = CoreDataPageBookmarkUniquifier()
                let note = CoreDataNoteUniquifier()
                return [lastPage, pageBookmark, note]
            }
            _coreDataStack = stack
            return stack
        } catch {
            logger.error("Failed to initialize CoreData stack: \(error)")
            crasher.recordError(error, reason: "CoreData initialization failed")
            
            // Create a minimal fallback stack for basic functionality
            // This should not normally happen, but prevents complete app failure
            do {
                let fallbackStack = try CoreDataStack(name: "QuranFallback", modelUrl: CoreDataModelResources.quranModel) {
                    return [] // No uniquifiers for fallback
                }
                _coreDataStack = fallbackStack
                return fallbackStack
            } catch {
                logger.error("Even fallback CoreData stack failed: \(error)")
                // This is a critical failure - the app cannot function without CoreData
                fatalError("Critical: Cannot initialize any CoreData stack. App cannot continue.")
            }
        }
    }
}

private enum Constant {
    static let wordsDatabase = Bundle.main
        .url(forResource: "words", withExtension: "db")!

    static let appHost: URL = URL(validURL: "https://quran.app/")

    static let filesAppHost: URL = URL(validURL: "https://files.quran.app/")

    static let databasesURL = FileManager.documentsURL
        .appendingPathComponent("databases", isDirectory: true)

    /// If set, the Quran.com login will be enabled.
    static let QuranOAuthAppConfigurations: AuthenticationClientConfiguration? = nil
}
