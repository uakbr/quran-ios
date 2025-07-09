//
//  DatabaseConnection.swift
//
//
//  Created by Mohamed Afifi on 2023-05-25.
//

import Combine
import Foundation
import GRDB
import Utilities
import VLogging

private struct DatabaseConnectionPool: Sendable {
    private struct Connection {
        let database: DatabaseWriter
        var references: Int
        let createdAt: Date
    }

    private struct State {
        var connections: [URL: Connection] = [:]
        var totalConnections: Int = 0
    }
    
    private static let maxTotalConnections = 10
    private static let connectionTimeout: TimeInterval = 30.0

    // MARK: Internal

    func database(for url: URL, readonly: Bool) throws -> DatabaseWriter {
        try state.withCriticalRegion { state in
            if var connection = state.connections[url] {
                connection.references += 1
                state.connections[url] = connection
                return connection.database
            }

            // Check if we're at the connection limit
            if state.totalConnections >= Self.maxTotalConnections {
                // Clean up old unused connections
                cleanupOldConnections(&state)
                
                // If still at limit, throw error
                if state.totalConnections >= Self.maxTotalConnections {
                    throw PersistenceError.tooManyConnections
                }
            }

            // Create the database folder if needed.
            try? FileManager.default.createDirectory(
                atPath: url.path.stringByDeletingLastPathComponent,
                withIntermediateDirectories: true,
                attributes: nil
            )

            let database = try newDatabase(url: url, readonly: readonly)
            let newConnection = Connection(database: database, references: 1, createdAt: Date())
            state.connections[url] = newConnection
            state.totalConnections += 1
            return newConnection.database
        }
    }

    func releaseDatabase(for url: URL) {
        state.withCriticalRegion { state in
            if var connection = state.connections[url] {
                connection.references -= 1
                if connection.references == 0 {
                    state.connections[url] = nil
                    state.totalConnections -= 1
                } else {
                    state.connections[url] = connection
                }
            }
        }
    }
    
    private func cleanupOldConnections(_ state: inout State) {
        let cutoff = Date().addingTimeInterval(-Self.connectionTimeout)
        let urlsToRemove = state.connections.compactMap { (url, connection) in
            connection.references == 0 && connection.createdAt < cutoff ? url : nil
        }
        
        for url in urlsToRemove {
            state.connections[url] = nil
            state.totalConnections -= 1
        }
    }

    // MARK: Private

    private let state = ManagedCriticalState(State())

    private func newDatabase(url: URL, readonly: Bool) throws -> DatabaseWriter {
        do {
            return try attempt(times: 3) {
                var configuration = Configuration()
                configuration.readonly = readonly
                // Optimized timeout and connection settings
                configuration.busyMode = .timeout(10) // Increased timeout
                configuration.maximumReaderCount = 5 // Limit concurrent readers
                
                // Enable WAL mode for better performance
                configuration.prepareDatabase { db in
                    try db.execute(sql: "PRAGMA journal_mode = WAL")
                    try db.execute(sql: "PRAGMA synchronous = NORMAL")
                    try db.execute(sql: "PRAGMA cache_size = 10000") // 10MB cache
                    try db.execute(sql: "PRAGMA temp_store = MEMORY")
                }
                
                return try DatabasePool(path: url.path, configuration: configuration)
            }
        } catch {
            logger.error("Cannot open sqlite file \(url). Error: \(error)")
            throw PersistenceError(error, databaseURL: url)
        }
    }
}

public final class DatabaseConnection: Sendable {
    private struct State {
        var database: DatabaseWriter?
    }

    // MARK: Lifecycle

    public init(url: URL, readonly: Bool = true) {
        databaseURL = url
        self.readonly = readonly
    }

    deinit {
        state.withCriticalRegion { state in
            if state.database != nil {
                Self.connectionPool.releaseDatabase(for: databaseURL)
            }
        }
    }

    // MARK: Public

    public func read<T>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        let database = try getDatabase()
        do {
            return try await database.read(block)
        } catch {
            logger.error("General error while executing query. Error: \(error).")
            throw PersistenceError(error, databaseURL: databaseURL)
        }
    }

    /// Creates a publisher that tracks changes in the results of database requests,
    /// and notifies fresh values whenever the database changes
    ///
    /// The first value is notified when the publisher is created. Subsequent changes *may* get coalesced in notifications.
    /// - ValueObservation may coalesce subsequent changes into a single notification
    /// - ValueObservation fetches a fresh value immediately after a change *is committed in the database*.
    /// - By default, delivers on the main thread.
    public func readPublisher<T>(_ block: @Sendable @escaping (Database) throws -> T) throws -> AnyPublisher<T, Error> {
        ValueObservation
            .tracking(block)
            .publisher(in: try getDatabase())
            .eraseToAnyPublisher()
    }

    public func write<T>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        let database = try getDatabase()
        do {
            return try await database.write(block)
        } catch {
            logger.error("General error while executing query. Error: \(error).")
            throw PersistenceError(error, databaseURL: databaseURL)
        }
    }

    // MARK: Internal

    let databaseURL: URL
    let readonly: Bool

    func getDatabase() throws -> DatabaseWriter {
        try state.withCriticalRegion { state in
            if let database = state.database {
                return database
            }

            let database = try Self.connectionPool.database(for: databaseURL, readonly: readonly)
            state.database = database
            return database
        }
    }

    // MARK: Private

    private static let connectionPool = DatabaseConnectionPool()

    private let state = ManagedCriticalState(State())
}

// MARK: - Performance Monitoring Extension

extension DatabaseConnection {
    /// Execute a block with performance monitoring
    public func readWithMetrics<T>(_ block: @Sendable @escaping (Database) throws -> T) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            if timeElapsed > 0.1 { // Log slow queries (>100ms)
                logger.warning("Slow database read query took \(timeElapsed)s for \(databaseURL.lastPathComponent)")
            }
        }
        return try await read(block)
    }
}

private extension PersistenceError {
    init(_ error: Error, databaseURL: URL) {
        let dbFileIssueCodes: [ResultCode] = [
            .SQLITE_PERM,
            .SQLITE_NOTADB,
            .SQLITE_CORRUPT,
            .SQLITE_CANTOPEN,
        ]

        if let error = error as? PersistenceError {
            self = error
        }
        if let error = error as? DatabaseError {
            if dbFileIssueCodes.contains(error.extendedResultCode) {
                // remove the db file as sometimes, the download is completed with error.
                try? FileManager.default.removeItem(at: databaseURL)
                logger.error("Bad file error while executing query. Error: \(error).")
                self = PersistenceError.badFile(error)
            }
        }
        self = PersistenceError.query(error)
    }
}

extension DatabaseMigrator {
    public func migrate(_ connection: DatabaseConnection) throws {
        let database = try connection.getDatabase()
        do {
            try migrate(database)
        } catch {
            throw PersistenceError(error, databaseURL: connection.databaseURL)
        }
    }
}
