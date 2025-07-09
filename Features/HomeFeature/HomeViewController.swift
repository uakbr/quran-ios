//
//  HomeViewController.swift
//
//
//  Created by Mohamed Afifi on 2023-07-16.
//

import Localization
import ReadingSelectorFeature
import SwiftUI
import UIx

final class HomeViewController: UIHostingController<HomeView> {
    // MARK: Lifecycle

    init(viewModel: HomeViewModel, readingSelectorBuilder: ReadingSelectorBuilder) {
        self.viewModel = viewModel
        self.readingSelectorBuilder = readingSelectorBuilder
        super.init(rootView: HomeView(viewModel: viewModel))

        initialize()
    }

    @available(*, unavailable)
    @MainActor
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private let viewModel: HomeViewModel
    private let readingSelectorBuilder: ReadingSelectorBuilder

    private func initialize() {
        configureNavigationBar()
    }

    private func configureNavigationBar() {
        // Set basic navigation properties
        title = l("tab.home")
        
        // Configure the reading selector button
        configureNavigationBarButtons()
    }

    private func configureNavigationBarButtons() {
        let readingSelectorButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat"),
            style: .plain,
            target: self,
            action: #selector(readingItemTapped)
        )
        readingSelectorButton.accessibilityLabel = l("settings.reading.title")
        
        navigationItem.rightBarButtonItem = readingSelectorButton
    }

    @objc
    private func readingItemTapped() {
        let readingSelectorViewController = readingSelectorBuilder.build()
        present(readingSelectorViewController, animated: true)
    }
}
