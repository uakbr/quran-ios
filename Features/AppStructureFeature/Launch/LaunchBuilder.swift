//
//  LaunchBuilder.swift
//  Quran
//
//  Created by Mohamed Afifi on 2022-01-09.
//  Copyright © 2022 Quran.com. All rights reserved.
//

import AppDependencies
import AppMigrationFeature
import AudioUpdater
import FeaturesSupport
import QuranKit
import ReciterService
import SettingsService
import UIKit
import VLogging

@MainActor
public struct LaunchBuilder {
    // MARK: Lifecycle

    public init(container: AppDependencies) {
        self.container = container
    }

    // MARK: Public

    public func launchStartup() -> LaunchStartup {
        let audioUpdater = AudioUpdater(baseURL: container.appHost)
        let fileSystemMigrator = FileSystemMigrator(
            databasesURL: container.databasesURL,
            recitersRetreiver: ReciterDataRetriever()
        )
        return LaunchStartup(
            appBuilder: AppBuilder(container: container),
            audioUpdater: audioUpdater,
            fileSystemMigrator: fileSystemMigrator,
            recitersPathMigrator: RecitersPathMigrator(),
            reviewService: ReviewService(analytics: container.analytics)
        )
    }

    public func handleIncomingUrl(urlContext: UIOpenURLContext) {
        let url = urlContext.url

        if url.scheme == "quran" || url.scheme == "quran-ios" {
            let path: String = if #available(iOS 16.0, *) {
                url.path(percentEncoded: true)
            } else {
                url.path
            }
            _ = navigateTo(path: path)
        }
    }

    // MARK: Internal

    let container: AppDependencies

    // MARK: Public

    private func navigateTo(path: String) -> Bool {
        logger.info("Deep link navigation: \(path)")
        
        // Find the active QuranNavigator from the app structure
        guard let navigator = findActiveQuranNavigator() else {
            logger.error("No active QuranNavigator found for deep linking")
            return false
        }
        
        // Parse the URL path and navigate accordingly
        if let route = parseRoute(from: path) {
            switch route {
            case .page(let pageNumber):
                if let page = Page(pageNumber) {
                    logger.info("Navigating to page: \(pageNumber)")
                    navigator.navigateTo(page: page, lastPage: nil, highlightingSearchAyah: nil)
                    return true
                }
                
            case .sura(let suraNumber, let ayahNumber):
                if let quran = findCurrentQuran(), 
                   let sura = quran.suras.first(where: { $0.suraNumber == suraNumber }) {
                    let ayah = ayahNumber.flatMap { AyahNumber(quran: quran, sura: suraNumber, ayah: $0) }
                    logger.info("Navigating to sura: \(suraNumber), ayah: \(ayahNumber ?? 1)")
                    navigator.navigateTo(page: sura.page, lastPage: nil, highlightingSearchAyah: ayah)
                    return true
                }
                
            case .verse(let suraNumber, let ayahNumber):
                if let quran = findCurrentQuran(),
                   let ayah = AyahNumber(quran: quran, sura: suraNumber, ayah: ayahNumber) {
                    logger.info("Navigating to verse: \(suraNumber):\(ayahNumber)")
                    navigator.navigateTo(page: ayah.page, lastPage: nil, highlightingSearchAyah: ayah)
                    return true
                }
            }
        }
        
        logger.warning("Unable to parse navigation path: \(path)")
        return false
    }
    
    private enum NavigationRoute {
        case page(Int)
        case sura(Int, ayah: Int?)
        case verse(sura: Int, ayah: Int)
    }
    
    private func parseRoute(from path: String) -> NavigationRoute? {
        // Remove leading slash
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let components = cleanPath.split(separator: "/").map(String.init)
        
        guard !components.isEmpty else { return nil }
        
        switch components[0].lowercased() {
        case "page":
            if components.count >= 2, let pageNumber = Int(components[1]) {
                return .page(pageNumber)
            }
            
        case "sura", "surah", "chapter":
            if components.count >= 2, let suraNumber = Int(components[1]) {
                let ayahNumber = components.count >= 3 ? Int(components[2]) : nil
                return .sura(suraNumber, ayah: ayahNumber)
            }
            
        case "verse", "ayah":
            if components.count >= 3,
               let suraNumber = Int(components[1]),
               let ayahNumber = Int(components[2]) {
                return .verse(sura: suraNumber, ayah: ayahNumber)
            }
            
        default:
            // Try parsing direct sura:ayah format (e.g., "2:255")
            if let colonIndex = cleanPath.firstIndex(of: ":") {
                let suraString = String(cleanPath[..<colonIndex])
                let ayahString = String(cleanPath[cleanPath.index(after: colonIndex)...])
                
                if let suraNumber = Int(suraString), let ayahNumber = Int(ayahString) {
                    return .verse(sura: suraNumber, ayah: ayahNumber)
                }
            }
            
            // Try parsing as just a sura number
            if let suraNumber = Int(cleanPath) {
                return .sura(suraNumber, ayah: nil)
            }
        }
        
        return nil
    }
    
    private func findActiveQuranNavigator() -> QuranNavigator? {
        // Get the active window and find a QuranNavigator
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return findQuranNavigator(in: rootViewController)
    }
    
    private func findQuranNavigator(in viewController: UIViewController) -> QuranNavigator? {
        // Check if the view controller itself is a QuranNavigator
        if let navigator = viewController as? QuranNavigator {
            return navigator
        }
        
        // Check tab bar controller
        if let tabBarController = viewController as? UITabBarController {
            if let selectedViewController = tabBarController.selectedViewController {
                return findQuranNavigator(in: selectedViewController)
            }
        }
        
        // Check navigation controller
        if let navigationController = viewController as? UINavigationController {
            if let topViewController = navigationController.topViewController {
                return findQuranNavigator(in: topViewController)
            }
        }
        
        // Check presented view controllers
        if let presentedViewController = viewController.presentedViewController {
            return findQuranNavigator(in: presentedViewController)
        }
        
        // Check child view controllers
        for child in viewController.children {
            if let navigator = findQuranNavigator(in: child) {
                return navigator
            }
        }
        
        return nil
    }
    
    private func findCurrentQuran() -> Quran? {
        // Use the default Quran for now (could be enhanced to use current reading preference)
        return Quran.hafsMadani1
    }
}
