//
//  LibraryView.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct LibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFiles: Set<ScannedFile.ID> = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Scanned Files")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                #if os(macOS)
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                #endif

                Button {
                    openInFinder()
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .padding()

            Divider()

            // File Grid
            if appState.scannedFiles.isEmpty {
                ContentUnavailableView {
                    Label("No Scanned Files", systemImage: "photo.stack")
                } description: {
                    Text("Your scanned photos will appear here")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredFiles) { file in
                            FileGridItem(file: file, isSelected: selectedFiles.contains(file.id))
                                .onTapGesture {
                                    if selectedFiles.contains(file.id) {
                                        selectedFiles.remove(file.id)
                                    } else {
                                        selectedFiles.insert(file.id)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private var filteredFiles: [ScannedFile] {
        if searchText.isEmpty {
            return appState.scannedFiles
        }
        return appState.scannedFiles.filter { $0.filename.localizedCaseInsensitiveContains(searchText) }
    }

    private func openInFinder() {
        #if os(macOS)
        let path = NSString(string: appState.scanDestination).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
        #endif
    }
}

struct FileGridItem: View {
    let file: ScannedFile
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.filename)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack {
                    Text(file.formattedSize)
                    Text("•")
                    Text("\(file.resolution) DPI")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LibraryView()
        .environment(AppState())
        .frame(width: 700, height: 500)
}
