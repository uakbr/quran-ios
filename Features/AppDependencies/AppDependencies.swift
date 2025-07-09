//
//  AppDependencies.swift
//
//
//  Created by Mohamed Afifi on 2023-06-18.
//

import Analytics
import AnnotationsService
import AuthenticationClient
import BatchDownloader
import Foundation
import LastPagePersistence
import NotePersistence
import PageBookmarkPersistence
import QuranResources
import QuranTextKit
import ReadingService

/// The main dependency injection protocol for the Quran Engine app.
///
/// This protocol defines all the core services and resources needed by the application.
/// It serves as the central contract for dependency injection, allowing different implementations
/// for different environments (production, testing, etc.).
///
/// ## Architecture
/// The protocol follows the dependency injection pattern to ensure loose coupling between
/// components and enable easier testing and modularity.
///
/// ## Usage
/// ```swift
/// class Container: AppDependencies {
///     // Implement all required properties
/// }
/// ```
public protocol AppDependencies {
    
    // MARK: - File System & URLs
    
    /// URL to the databases directory where all Quran-related databases are stored
    var databasesURL: URL { get }
    
    /// URL to the main Quran database (Uthmani script version 2)
    var quranUthmaniV2Database: URL { get }
    
    /// URL to the words database containing word-level information
    var wordsDatabase: URL { get }
    
    /// Base URL for the application's remote API services
    var appHost: URL { get }
    
    /// Base URL for file downloads and static resources
    var filesAppHost: URL { get }
    
    /// Directory where application logs are stored
    var logsDirectory: URL { get }
    
    /// Directory where all databases are stored
    var databasesDirectory: URL { get }

    // MARK: - Feature Flags
    
    /// Whether the app supports CloudKit for data synchronization
    var supportsCloudKit: Bool { get }

    // MARK: - Core Services
    
    /// Service for managing file downloads and background downloads
    var downloadManager: DownloadManager { get }
    
    /// Analytics service for tracking user events and app performance
    var analytics: AnalyticsLibrary { get }
    
    /// Service for managing reading resources (texts, translations, etc.)
    var readingResources: ReadingResourcesService { get }
    
    /// Optional service for remote reading resources
    var remoteResources: ReadingRemoteResources? { get }

    // MARK: - Persistence Services
    
    /// Service for persisting and retrieving the user's last read page
    var lastPagePersistence: LastPagePersistence { get }
    
    /// Service for managing user notes and annotations
    var notePersistence: NotePersistence { get }
    
    /// Service for managing bookmarked pages
    var pageBookmarkPersistence: PageBookmarkPersistence { get }

    // MARK: - Authentication
    
    /// Optional authentication client for user login and OAuth flows
    var authenticationClient: (any AuthenticationClient)? { get }
}

// MARK: - Default Implementations

extension AppDependencies {
    /// Default implementation using the bundled Quran database
    public var quranUthmaniV2Database: URL { QuranResources.quranUthmaniV2Database }

    /// Creates a text data service for Quran text operations
    /// - Returns: Configured QuranTextDataService instance
    public func textDataService() -> QuranTextDataService {
        QuranTextDataService(
            databasesURL: databasesURL,
            quranFileURL: quranUthmaniV2Database
        )
    }

    /// Creates a note service for managing user notes
    /// - Returns: Configured NoteService instance with all required dependencies
    public func noteService() -> NoteService {
        NoteService(
            persistence: notePersistence,
            textService: textDataService(),
            analytics: analytics
        )
    }
}
