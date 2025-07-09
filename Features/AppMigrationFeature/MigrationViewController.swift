//
//  MigrationViewController.swift
//  Quran
//
//  Created by Afifi, Mohamed on 8/8/20.
//  Copyright © 2020 Quran.com. All rights reserved.
//

import NoorUI
import SwiftUI

public class MigrationViewController: UIHostingController<MigrationView> {
    // MARK: Lifecycle

    public init() {
        let viewModel = MigrationViewModel()
        super.init(rootView: MigrationView(viewModel: viewModel))
        self.viewModel = viewModel
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    public func setTitles(_ titles: Set<String>) {
        viewModel.setTitles(titles)
    }

    // MARK: Private

    private let viewModel: MigrationViewModel
}

// MARK: - SwiftUI View

public struct MigrationView: View {
    @StateObject var viewModel: MigrationViewModel
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background color
                Color.systemBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // App Icon or Logo
                    Image(systemName: "book.quran")
                        .font(.system(size: 80))
                        .foregroundColor(.primary)
                    
                    // Migration text
                    if !viewModel.titles.isEmpty {
                        VStack(spacing: 16) {
                            Text("Upgrading App")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(viewModel.titles), id: \.self) { title in
                                    Text(title)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    
                    // Activity Indicator
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.2)
                        .tint(.accentColor)
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
public class MigrationViewModel: ObservableObject {
    @Published var titles: Set<String> = []
    
    public init() {}
    
    public func setTitles(_ titles: Set<String>) {
        self.titles = titles
    }
}

// MARK: - Preview

struct MigrationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            MigrationView(viewModel: MigrationViewModel())
                .previewDisplayName("Empty State")
            
            // With titles
            MigrationView(viewModel: {
                let vm = MigrationViewModel()
                vm.setTitles(["Updating audio files", "Migrating user data", "Optimizing database"])
                return vm
            }())
            .previewDisplayName("With Migration Tasks")
        }
    }
}
