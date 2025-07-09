//
//  BookmarksTab.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/14/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import AppDependencies
import BookmarksFeature
import Localization
import QuranViewFeature
import UIKit

struct BookmarksTabBuilder: TabBuildable {
    let container: AppDependencies

    func build() -> UIViewController {
        let interactor = BookmarksTabInteractor(
            quranBuilder: QuranBuilder(container: container),
            bookmarksBuilder: BookmarksBuilder(container: container)
        )
        let viewController = BookmarksTabViewController(interactor: interactor)
        viewController.navigationBar.prefersLargeTitles = true
        return viewController
    }
}

private final class BookmarksTabInteractor: TabInteractor {
    // MARK: Lifecycle

    init(quranBuilder: QuranBuilder, bookmarksBuilder: BookmarksBuilder) {
        self.bookmarksBuilder = bookmarksBuilder
        super.init(quranBuilder: quranBuilder)
    }

    // MARK: Internal

    override func start() {
        let rootViewController = bookmarksBuilder.build(withListener: self)
        presenter?.setViewControllers([rootViewController], animated: false)
    }

    // MARK: Private

    private let bookmarksBuilder: BookmarksBuilder
}

private class BookmarksTabViewController: TabViewController {
    override func getTabBarItem() -> UITabBarItem {
        let item = UITabBarItem(
            title: l("tab.bookmarks"),
            image: .symbol("bookmark"),
            selectedImage: .symbol("bookmark.fill")
        )
        item.accessibilityLabel = "Bookmarks"
        item.accessibilityHint = "View and manage your bookmarked pages"
        item.accessibilityIdentifier = "BookmarksTab"
        return item
    }
}
