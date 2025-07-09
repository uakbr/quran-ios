//
//  SearchViewModel.swift
//
//
//  Created by Mohamed Afifi on 2023-07-17.
//

import Analytics
import Combine
import Dispatch
import QuranKit
import QuranText
import QuranTextKit
import ReadingService
import TranslationService
import VLogging

@MainActor
final class SearchViewModel: ObservableObject {
    // MARK: Lifecycle

    init(analytics: AnalyticsLibrary, searchService: CompositeSearcher, navigateTo: @escaping (AyahNumber) -> Void) {
        self.analytics = analytics
        self.searchService = searchService
        self.navigateTo = navigateTo
    }

    // MARK: Internal

    @Published var error: Error? = nil

    @Published var searchState = SearchState.searching

    @Published var searchTerm = ""
    @Published var autocompletions: [String] = []
    @Published var recents: [String] = []

    @Published var keyboardState: KeyboardState = .closed

    @Published var uiState = SearchUIState.entry {
        didSet {
            logger.debug("[Search] New UI state: \(uiState)")
        }
    }

    var populars: [String] { recentsService.popularTerms }

    func start() async {
        async let reading: () = observeReadingChanges()
        async let autocomplete: () = observeSearchTermChanges()
        async let recents: () = observeRecentSearchItemsChanges()
        async let search: () = observeSearchChanges()
        _ = await [reading, autocomplete, recents, search]
    }

    func searchSelected(_ term: String) {
        searchTerm = term
        uiState = .search(term)
    }

    func navigateTo(_ verse: AyahNumber) {
        analytics.searchResultTapped()
        navigateTo(verse)
    }
    
    func select(searchResult: SearchResult, source: SearchResults.Source) {
        logger.info("Search: search result selected '\(searchResult)', source: \(source)")
        // show translation if not an active translation
        switch source {
        case .quran: break
        case .translation(let translation):
            contentStatePreferences.quranMode = .translation
            var translationIds = selectedTranslationsPreferences.selectedTranslationIds
            if !translationIds.contains(translation.id) {
                translationIds.append(translation.id)
                selectedTranslationsPreferences.selectedTranslationIds = translationIds
            }
        }

        // navigate to the selected page
        analytics.openingQuran(from: .searchResults)
        navigateTo(searchResult.ayah)
    }

    func reset() {
        uiState = .entry
        searchTerm = ""
        autocompletions = []
        // Cancel any ongoing search
        searchTask?.cancel()
    }

    func autocomplete(_ term: String) {
        if searchTerm != term {
            uiState = .entry
            searchTerm = term
        }
    }

    func searchForUserTypedTerm() {
        search(for: searchTerm)
    }

    func search(for term: String) {
        keyboardState = .closed
        searchTerm = term
        uiState = .search(term)
    }

    // MARK: Private

    private let analytics: AnalyticsLibrary
    private let searchService: CompositeSearcher
    private let navigateTo: (AyahNumber) -> Void
    private let readingPreferences = ReadingPreferences.shared
    private let recentsService = SearchRecentsService.shared
    private let contentStatePreferences = QuranContentStatePreferences.shared
    private let selectedTranslationsPreferences = SelectedTranslationsPreferences.shared

    // MARK: - Search Performance Optimization
    
    private var searchTask: Task<Void, Never>?
    private let searchQueue = DispatchQueue(label: "SearchQueue", qos: .userInitiated)

    private func search(for term: String) async throws -> [SearchResults] {
        // Cancel any ongoing search to prevent resource waste
        searchTask?.cancel()
        
        return try await withCheckedThrowingContinuation { continuation in
            searchTask = Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                do {
                    // Perform search on background queue for better performance
                    let quran = await self.readingPreferences.reading.quran
                    let results = try await self.searchService.search(for: term, quran: quran)

                    // Only update analytics and recents on successful search
                    await MainActor.run {
                        self.analytics.searching(for: term, results: results)
                        self.recentsService.addToRecents(term)
                    }

                    continuation.resume(returning: results)
                } catch {
                    if !(error is CancellationError) {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func observeSearchChanges() async {
        let states = $uiState.values()
        for await state in states {
            switch state {
            case .entry:
                // Cancel any ongoing search when returning to entry
                searchTask?.cancel()
                continue
            case .search(let term):
                await MainActor.run {
                    self.searchState = .searching
                }
                
                let result = await Result(catching: { try await search(for: term) })
                
                // Ensure we're still searching for the same term
                await MainActor.run {
                    if self.searchTerm == term {
                        switch result {
                        case .success(let results):
                            self.searchState = .searchResult(results)
                        case .failure(let error):
                            self.error = error
                            self.searchState = .searchResult([])
                        }
                    }
                }
            }
        }
    }

    private func observeSearchTermChanges() async {
        // Debounce search term changes to avoid excessive autocomplete requests
        let searchTermSequence = $searchTerm
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .values()

        for await term in searchTermSequence {
            guard !term.isEmpty else {
                autocompletions = []
                continue
            }

            // Perform autocomplete on background queue
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                
                let quran = await self.readingPreferences.reading.quran
                let suggestions = await self.searchService.autocomplete(term: term, quran: quran)
                
                await MainActor.run {
                    // Only update if this is still the current search term
                    if self.searchTerm == term {
                        self.autocompletions = suggestions
                    }
                }
            }
        }
    }

    private func observeRecentSearchItemsChanges() async {
        let recentsSequence = recentsService.$recentSearchItems
            .prepend(recentsService.recentSearchItems)
            .values()
        for await recents in recentsSequence {
            self.recents = recents
        }
    }

    private func observeReadingChanges() async {
        let readings = readingPreferences.$reading
            .values()
        for await _ in readings {
            searchTerm = ""
            // Cancel any ongoing search when reading changes
            searchTask?.cancel()
        }
    }
}

private extension AnalyticsLibrary {
    func searching(for term: String, results: [SearchResults]) {
        logEvent("SearchTerm", value: term)
        logEvent("SearchSections", value: results.count.description)
        for result in results {
            logEvent("SearchSource", value: result.source.name)
            logEvent("SearchResultsCount", value: result.items.count.description)
        }
    }
    
    func searchResultTapped() {
        logEvent("SearchResultTapped")
    }
}

private extension SearchResults.Source {
    var name: String {
        switch self {
        case .quran:
            return "Quran"
        case .translation(let translation):
            return "Translation-\(translation.id)"
        }
    }
}
