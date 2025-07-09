//
//  OAuthService.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 08/01/2025.
//

import Foundation
import UIKit

/// Errors that can occur during OAuth operations
public enum OAuthServiceError: Error {
    /// Failed to refresh access tokens
    case failedToRefreshTokens(Error?)

    /// Failed to decode OAuth state data
    case stateDataDecodingError(Error?)

    /// Failed to discover OAuth service configuration
    case failedToDiscoverService(Error?)

    /// Failed to authenticate the user
    case failedToAuthenticate(Error?)
}

extension OAuthServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .failedToRefreshTokens(let error):
            return "Failed to refresh OAuth tokens: \(error?.localizedDescription ?? "Unknown error")"
        case .stateDataDecodingError(let error):
            return "Failed to decode OAuth state: \(error?.localizedDescription ?? "Unknown error")"
        case .failedToDiscoverService(let error):
            return "Failed to discover OAuth service: \(error?.localizedDescription ?? "Unknown error")"
        case .failedToAuthenticate(let error):
            return "Authentication failed: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}

/// Encapsulates the OAuth state data and authorization status.
///
/// This protocol represents the current OAuth state including tokens, user information,
/// and authorization status. The state should be treated as opaque by client code and
/// only managed through the `OAuthService`.
///
/// ## Security Considerations
/// - Implementations should ensure sensitive data (tokens) are properly protected
/// - State data should be encrypted when persisted
/// - Access to tokens should be controlled and audited
///
/// ## Usage
/// ```swift
/// if stateData.isAuthorized {
///     // User is logged in, can make authenticated requests
///     let (token, newState) = try await service.getAccessToken(using: stateData)
/// }
/// ```
public protocol OAuthStateData {
    /// Whether the user is currently authorized (has valid tokens)
    ///
    /// This property indicates if the user has completed the OAuth flow and
    /// has valid credentials. It does not guarantee that tokens are still valid
    /// (they may have expired), only that authorization was completed.
    var isAuthorized: Bool { get }
}

/// An abstraction for handling OAuth 2.0 authorization flows.
///
/// This service implements the OAuth 2.0 Authorization Code flow with PKCE
/// (Proof Key for Code Exchange) for secure authentication in mobile applications.
/// The service follows OAuth 2.0 Security Best Current Practice guidelines.
///
/// ## Security Features
/// - PKCE (Proof Key for Code Exchange) for authorization code protection
/// - Secure token storage and management
/// - Automatic token refresh when possible
/// - Protection against authorization code interception
///
/// ## Architecture
/// The service is designed to be stateless - all OAuth state is managed by the client
/// through the `OAuthStateData` protocol. This allows for flexible state persistence
/// and better testability.
///
/// ## OAuth Flow
/// 1. **Discovery**: Service discovers OAuth provider configuration
/// 2. **Authorization**: User is redirected to provider for authentication
/// 3. **Code Exchange**: Authorization code is exchanged for tokens
/// 4. **Token Management**: Access tokens are refreshed as needed
///
/// ## Usage Example
/// ```swift
/// let oauthService = OAuth2Service()
/// 
/// // Step 1: Login
/// let stateData = try await oauthService.login(on: viewController)
/// 
/// // Step 2: Get access token for API calls
/// let (accessToken, updatedState) = try await oauthService.getAccessToken(using: stateData)
/// 
/// // Step 3: Refresh tokens when needed
/// let refreshedState = try await oauthService.refreshAccessTokenIfNeeded(data: updatedState)
/// ```
///
/// ## Thread Safety
/// All methods are async and designed to be called from any queue. The service
/// handles thread safety internally.
public protocol OAuthService {
    
    /// Initiates the OAuth authorization flow
    ///
    /// This method performs service discovery to find the OAuth provider's configuration,
    /// then redirects the user to the authorization server for authentication.
    /// The method uses PKCE for additional security.
    ///
    /// - Parameter viewController: The view controller to present the authorization UI from
    /// - Returns: OAuth state data containing the authorization result
    /// - Throws: 
    ///   - `OAuthServiceError.failedToDiscoverService` if service discovery fails
    ///   - `OAuthServiceError.failedToAuthenticate` if user authentication fails
    ///
    /// ## Flow Details
    /// 1. Discovers OAuth provider configuration (endpoints, capabilities)
    /// 2. Generates PKCE code verifier and challenge
    /// 3. Redirects user to authorization server
    /// 4. Handles authorization response and exchanges code for tokens
    ///
    /// ## Security Notes
    /// - Uses PKCE to protect against authorization code interception
    /// - Validates redirect URIs to prevent authorization code injection
    /// - Implements state parameter for CSRF protection
    func login(on viewController: UIViewController) async throws -> OAuthStateData

    /// Retrieves a valid access token for API authentication
    ///
    /// This method returns a valid access token, automatically refreshing it if
    /// necessary. The returned state data reflects any token updates.
    ///
    /// - Parameter data: Current OAuth state data
    /// - Returns: Tuple containing the access token and updated state data
    /// - Throws: 
    ///   - `OAuthServiceError.failedToRefreshTokens` if token refresh fails
    ///   - `OAuthServiceError.stateDataDecodingError` if state data is invalid
    ///
    /// ## Usage
    /// ```swift
    /// let (token, newState) = try await service.getAccessToken(using: currentState)
    /// // Use token for API requests
    /// api.makeRequest(withToken: token)
    /// // Update stored state
    /// persistState(newState)
    /// ```
    ///
    /// ## Token Lifecycle
    /// - Checks if current access token is valid
    /// - Automatically refreshes token if expired and refresh token is available
    /// - Returns fresh token for immediate use
    func getAccessToken(using data: OAuthStateData) async throws -> (String, OAuthStateData)

    /// Refreshes access tokens if they are expired or about to expire
    ///
    /// This method proactively refreshes tokens before they expire to ensure
    /// uninterrupted access to protected resources. It's recommended to call
    /// this method periodically or before making API requests.
    ///
    /// - Parameter data: Current OAuth state data
    /// - Returns: Updated OAuth state data with refreshed tokens
    /// - Throws: `OAuthServiceError.failedToRefreshTokens` if refresh fails
    ///
    /// ## Best Practices
    /// - Call this method before making API requests
    /// - Handle refresh failures gracefully (may require re-authentication)
    /// - Update persisted state with returned data
    ///
    /// ## Token Refresh Strategy
    /// - Checks token expiration times
    /// - Refreshes tokens before they expire (with buffer time)
    /// - Uses refresh token rotation for enhanced security
    func refreshAccessTokenIfNeeded(data: OAuthStateData) async throws -> OAuthStateData
}

/// Handles encoding and decoding of OAuth state data for persistence
///
/// This protocol provides a convenient abstraction for persisting OAuth state
/// while hiding the concrete implementation type. This is useful for dependency
/// injection and testing scenarios.
///
/// ## Security Considerations
/// - Encoded data should be encrypted before storage
/// - Consider using secure storage mechanisms (Keychain, encrypted files)
/// - Validate data integrity during decoding
///
/// ## Usage
/// ```swift
/// let encoder = OAuth2StateEncoder()
/// 
/// // Persist state
/// let encodedData = try encoder.encode(oauthState)
/// try secureStorage.store(encodedData, forKey: "oauth_state")
/// 
/// // Restore state
/// let storedData = try secureStorage.retrieve(forKey: "oauth_state")
/// let restoredState = try encoder.decode(storedData)
/// ```
public protocol OAuthStateDataEncoder {
    
    /// Encodes OAuth state data for persistence
    /// - Parameter data: The OAuth state data to encode
    /// - Returns: Encoded data ready for storage
    /// - Throws: Encoding errors if data cannot be serialized
    func encode(_ data: OAuthStateData) throws -> Data

    /// Decodes OAuth state data from storage
    /// - Parameter data: The encoded data to decode
    /// - Returns: Decoded OAuth state data
    /// - Throws: 
    ///   - Decoding errors if data is corrupted or incompatible
    ///   - `OAuthServiceError.stateDataDecodingError` if decoding fails
    func decode(_ data: Data) throws -> OAuthStateData
}
