//
//  SearchTab.swift
//  Quran
//
//  Created by Afifi, Mohamed on 11/14/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import AppDependencies
import QuranViewFeature
import SearchFeature
import UIKit

struct SearchTabBuilder: TabBuildable {
    let container: AppDependencies

    func build() -> UIViewController {
        let interactor = SearchTabInteractor(
            quranBuilder: QuranBuilder(container: container),
            searchBuilder: SearchBuilder(container: container)
        )
        let viewController = SearchTabViewController(interactor: interactor)
        viewController.navigationBar.prefersLargeTitles = true
        return viewController
    }
}

private final class SearchTabInteractor: TabInteractor {
    // MARK: Lifecycle

    init(quranBuilder: QuranBuilder, searchBuilder: SearchBuilder) {
        self.searchBuilder = searchBuilder
        super.init(quranBuilder: quranBuilder)
    }

    // MARK: Internal

    override func start() {
        let rootViewController = searchBuilder.build(withListener: self)
        presenter?.setViewControllers([rootViewController], animated: false)
    }

    // MARK: Private

    private let searchBuilder: SearchBuilder
}

private class SearchTabViewController: TabViewController {
    override func getTabBarItem() -> UITabBarItem {
        let item = UITabBarItem(
            title: l("tab.search"),
            image: .symbol("magnifyingglass"),
            selectedImage: .symbol("magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(weight: .bold))
        )
        item.accessibilityLabel = "Search"
        item.accessibilityHint = "Search through Quran text"
        item.accessibilityIdentifier = "SearchTab"
        return item
    }
}
