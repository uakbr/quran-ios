//
//  NetworkManager.swift
//
//
//  Created by Afifi, Mohamed on 10/30/21.
//

import Foundation

/// A lightweight HTTP client for making network requests
///
/// NetworkManager provides a simple interface for making HTTP GET requests with query parameters.
/// It's designed to be lightweight and focused on the specific needs of the Quran Engine app.
///
/// ## Features
/// - Async/await support for modern concurrency
/// - Automatic query parameter encoding
/// - Error handling with localized error messages
/// - Configurable base URL for different environments
/// - Protocol-based session abstraction for testing
///
/// ## Usage
/// ```swift
/// let manager = NetworkManager(baseURL: URL(string: "https://api.example.com")!)
/// 
/// do {
///     let data = try await manager.request("/books", parameters: [
///         ("query", "swift"),
///         ("limit", "10")
///     ])
///     // Process response data
/// } catch {
///     // Handle network error
/// }
/// ```
///
/// ## Error Handling
/// All network errors are wrapped in `NetworkError` which provides localized
/// error messages and categorizes different types of network failures.
///
/// ## Thread Safety
/// This class is thread-safe and can be called from any queue. All methods
/// use async/await for proper concurrency handling.
public final class NetworkManager {
    // MARK: Lifecycle

    /// Creates a new NetworkManager instance
    /// - Parameters:
    ///   - session: The network session to use for requests (defaults to URLSession.shared)
    ///   - baseURL: The base URL for all requests
    public init(session: NetworkSession = URLSession.shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: Public

    /// Makes an HTTP GET request to the specified path
    ///
    /// This method constructs a full URL by combining the base URL with the provided path,
    /// adds query parameters, and performs the request.
    ///
    /// - Parameters:
    ///   - path: The API endpoint path (will be appended to baseURL)
    ///   - parameters: Query parameters as key-value pairs
    /// - Returns: The response data from the server
    /// - Throws: `NetworkError` if the request fails
    ///
    /// ## Example
    /// ```swift
    /// // Request: GET https://api.example.com/search?q=swift&limit=10
    /// let data = try await manager.request("/search", parameters: [
    ///     ("q", "swift"),
    ///     ("limit", "10")
    /// ])
    /// ```
    ///
    /// ## Error Handling
    /// This method wraps all networking errors in `NetworkError` which provides:
    /// - User-friendly error messages
    /// - Categorization of network failure types
    /// - Proper localization support
    public func request(_ path: String, parameters: [(String, String)] = []) async throws -> Data {
        do {
            let request: URLRequest = Self.request(baseURL: baseURL, path: path, parameters: parameters)
            let (data, _) = try await session.data(for: request)
            return data
        } catch {
            throw NetworkError(error: error)
        }
    }

    // MARK: Internal

    /// Constructs a URLRequest from the given parameters
    ///
    /// This is a static utility method that can be used for testing or creating
    /// requests without a NetworkManager instance.
    ///
    /// - Parameters:
    ///   - baseURL: The base URL for the request
    ///   - path: The path to append to the base URL
    ///   - parameters: Query parameters to add to the URL
    /// - Returns: A configured URLRequest ready for execution
    ///
    /// ## Implementation Details
    /// - Uses URLComponents for proper URL construction
    /// - Automatically percent-encodes query parameters
    /// - Maintains proper URL structure with path components
    static func request(baseURL: URL, path: String, parameters: [(String, String)] = []) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = parameters.map { URLQueryItem(name: $0, value: $1) }
        return URLRequest(url: components.url!)
    }

    // MARK: Private

    /// The network session used for making requests
    private let session: NetworkSession
    
    /// The base URL for all API requests
    private let baseURL: URL
}
