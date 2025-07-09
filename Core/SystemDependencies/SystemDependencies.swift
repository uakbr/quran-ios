//
//  SystemDependencies.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 08/01/2025.
//

import Foundation

/// A centralized access point for system dependencies
///
/// SystemDependencies provides a clean interface to various system services,
/// allowing for easy testing and dependency injection throughout the app.
public enum SystemDependencies {
    /// Provides access to keychain services for secure data storage
    public static let keychainAccess: any KeychainAccess = DefaultKeychainAccess()
    
    /// Provides access to file system operations
    public static let fileSystem: any FileSystem = DefaultFileSystem()
    
    /// Provides access to system time functionality
    public static let systemTime: any SystemTime = DefaultSystemTime()
    
    /// Provides access to zip/unzip functionality
    public static let zipper: any Zipper = DefaultZipper()
} 