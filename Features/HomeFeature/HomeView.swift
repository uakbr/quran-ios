//
//  HomeView.swift
//
//
//  Created by Mohamed Afifi on 2023-07-16.
//

import Localization
import NoorUI
import QuranAnnotations
import QuranKit
import SwiftUI
import UIx

struct HomeView: View {
    @StateObject var viewModel: HomeViewModel

    var body: some View {
        HomeViewUI(
            type: viewModel.type,
            lastPages: viewModel.lastPages,
            suras: viewModel.suras,
            quarters: viewModel.quarters,
            start: { await viewModel.start() },
            selectLastPage: { viewModel.navigateTo($0) },
            selectSura: { viewModel.navigateTo($0) },
            selectQuarter: { viewModel.navigateTo($0) },
            surahSortOrder: viewModel.surahSortOrder,
            toggleSortOrder: { viewModel.toggleSurahSortOrder() },
            setViewType: { viewModel.type = $0 }
        )
    }
}

private struct HomeViewUI: View {
    let type: HomeViewType
    let lastPages: [LastPage]
    let suras: [Sura]
    let quarters: [QuarterItem]
    let surahSortOrder: SurahSortOrder

    let start: AsyncAction
    let selectLastPage: ItemAction<Page>
    let selectSura: ItemAction<Sura>
    let selectQuarter: ItemAction<QuarterItem>
    let toggleSortOrder: Action
    let setViewType: ItemAction<HomeViewType>

    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented control
            HomeSegmentedControl(
                selectedType: type,
                onSelectionChanged: setViewType
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Main content
            contentView
        }
        .task { await start() }
    }

    @ViewBuilder
    private var contentView: some View {
        switch type {
        case .suras:
            surasView
        case .juzs:
            quartersView
        }
    }

    private var surasView: some View {
        NoorList {
            if !lastPages.isEmpty {
                lastPagesSection
            }
            surasSection
        }
    }

    private var quartersView: some View {
        NoorList {
            if !lastPages.isEmpty {
                lastPagesSection
            }
            quartersSection
        }
    }

    private var lastPagesSection: some View {
        NoorSection(title: l("home.recent"), lastPages) { lastPage in
            NoorListItem(
                title: .text(lastPage.suraName),
                subheading: lastPage.pageDescription,
                accessory: .text(NumberFormatter.shared.format(lastPage.page.pageNumber))
            ) {
                selectLastPage(lastPage.page)
            }
            .accessibilityIdentifier("recent_page_\(lastPage.page.pageNumber)")
            .accessibilityLabel("\(lastPage.suraName), \(lastPage.pageDescription)")
            .accessibilityHint(l("accessibility.tap-to-open-page"))
        }
    }

    private var surasSection: some View {
        NoorSection(
            title: l("home.suras"),
            titleAccessory: sortButton
        ) {
            LazyVStack {
                let sortedSuras = surahSortOrder == .ascending ? suras : suras.reversed()
                ForEach(sortedSuras) { sura in
                    NoorListItem(
                        title: .text(sura.localizedName(withNumber: true, arabicName: true)),
                        accessory: .text(NumberFormatter.shared.format(sura.firstPageNumber))
                    ) {
                        selectSura(sura)
                    }
                    .accessibilityIdentifier("sura_\(sura.suraNumber)")
                    .accessibilityLabel(sura.localizedName(withNumber: true, arabicName: false))
                    .accessibilityValue("Page \(sura.firstPageNumber)")
                    .accessibilityHint(l("accessibility.tap-to-open-sura"))
                }
            }
        }
    }

    private var quartersSection: some View {
        NoorSection(title: l("home.quarters")) {
            LazyVStack {
                ForEach(quarters) { quarterItem in
                    NoorListItem(
                        title: .text(quarterItem.quarter.localizedName()),
                        subheading: quarterItem.ayahText,
                        accessory: .text(NumberFormatter.shared.format(quarterItem.quarter.firstPageNumber))
                    ) {
                        selectQuarter(quarterItem)
                    }
                    .accessibilityIdentifier("quarter_\(quarterItem.quarter.number)")
                    .accessibilityLabel(quarterItem.quarter.localizedName())
                    .accessibilityValue("Page \(quarterItem.quarter.firstPageNumber)")
                    .accessibilityHint(l("accessibility.tap-to-open-quarter"))
                }
            }
        }
    }

    private var sortButton: some View {
        Button(action: toggleSortOrder) {
            Image(systemName: surahSortOrder == .ascending ? "arrow.up" : "arrow.down")
                .foregroundColor(.accentColor)
        }
        .accessibilityLabel(l("home.sort-suras"))
        .accessibilityHint(surahSortOrder == .ascending ? l("accessibility.sort-descending") : l("accessibility.sort-ascending"))
    }
}

// MARK: - Custom Segmented Control

private struct HomeSegmentedControl: View {
    let selectedType: HomeViewType
    let onSelectionChanged: ItemAction<HomeViewType>
    
    var body: some View {
        HStack(spacing: 0) {
            segmentButton(for: .suras, title: lAndroid("quran_sura"))
            segmentButton(for: .juzs, title: lAndroid("quran_juz2"))
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondarySystemGroupedBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.separator, lineWidth: 0.5)
        )
    }
    
    private func segmentButton(for type: HomeViewType, title: String) -> some View {
        Button(action: { onSelectionChanged(type) }) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(selectedType == type ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedType == type ? Color.accentColor : Color.clear)
                        .animation(.easeInOut(duration: 0.2), value: selectedType)
                )
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(selectedType == type ? .isSelected : [])
    }
}

struct HomeView_Previews: PreviewProvider {
    struct Preview: View {
        static let ayahText = "وَإِذۡ قَالَ مُوسَىٰ لِقَوۡمِهِۦ يَٰقَوۡمِ إِنَّكُمۡ ظَلَمۡتُمۡ أَنفُسَكُم بِٱتِّخَاذِكُمُ ٱلۡعِجۡلَ فَتُوبُوٓاْ إِلَىٰ بَارِئِكُمۡ فَٱقۡتُلُوٓاْ أَنفُسَكُمۡ ذَٰلِكُمۡ خَيۡرٞ لَّكُمۡ عِندَ بَارِئِكُمۡ فَتَابَ عَلَيۡكُمۡۚ إِنَّهُۥ هُوَ ٱلتَّوَّابُ ٱلرَّحِيمُ"

        static var staticLastPages: [LastPage] {
            let pages = Quran.hafsMadani1405.pages.shuffled()
            return (0 ..< 3).map { i in
                LastPage(
                    page: pages[i],
                    createdOn: Date(timeIntervalSince1970: Double(i) * 60 * -3),
                    modifiedOn: Date(timeIntervalSince1970: Double(i) * 60 * -3)
                )
            }
        }

        let quran = Quran.hafsMadani1405

        @State var lastPages: [LastPage] = staticLastPages
        @State var type: HomeViewType = .juzs

        var body: some View {
            NavigationView {
                HomeViewUI(
                    type: type,
                    lastPages: lastPages,
                    suras: quran.suras,
                    quarters: quran.quarters.map { QuarterItem(quarter: $0, ayahText: Self.ayahText) },
                    start: {},
                    selectLastPage: { _ in },
                    selectSura: { _ in },
                    selectQuarter: { _ in },
                    surahSortOrder: .ascending,
                    toggleSortOrder: {},
                    setViewType: { _ in }
                )
                .navigationTitle("Home")
                .toolbar {
                    if type == .suras {
                        Button("Juzs") { type = .juzs }
                    } else {
                        Button("Suras") { type = .suras }
                    }

                    if lastPages.isEmpty {
                        Button("Populate Last Pages") { lastPages = Self.staticLastPages }
                    } else {
                        Button("Empty") { lastPages = [] }
                    }
                }
            }
        }
    }

    // MARK: Internal

    static var previews: some View {
        VStack {
            Preview()
        }
    }
}
