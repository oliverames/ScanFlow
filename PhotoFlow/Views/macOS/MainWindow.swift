//
//  MainWindow.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

#if os(macOS)
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "MainWindow")

struct MainWindow: View {
    @Environment(AppState.self) private var appState
    @State private var hasSelectedScanner = false

    var body: some View {
        @Bindable var appState = appState

        Group {
            if hasSelectedScanner || appState.scannerManager.connectionState.isConnected {
                mainContentView
            } else {
                ScannerSelectionView(hasSelectedScanner: $hasSelectedScanner)
            }
        }
        .alert("Error", isPresented: $appState.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(appState.alertMessage)
        }
        .onChange(of: appState.scannerManager.connectionState) { oldState, newState in
            logger.info("Connection state changed: \(oldState.description) -> \(newState.description)")
            // If we disconnect, go back to scanner selection
            if case .disconnected = newState, oldState.isConnected {
                logger.info("Scanner disconnected, returning to selection view")
                hasSelectedScanner = false
            }
        }
    }

    private var mainContentView: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 700, ideal: 900)
        }
        .navigationSplitViewStyle(.balanced)
        .background(.ultraThinMaterial)
        .onAppear {
            logger.info("Main content view appeared")
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                ScannerStatusView()

                Spacer()

                // Change Scanner button
                Button {
                    logger.info("User requested scanner change")
                    hasSelectedScanner = false
                    Task {
                        await appState.scannerManager.disconnect()
                    }
                } label: {
                    Label("Change Scanner", systemImage: "scanner")
                }
                .help("Change Scanner")

                Menu {
                    Button("Quick Scan (300 DPI)") {
                        appState.currentPreset = ScanPreset.defaults[0]
                    }
                    Button("Archive Quality (600 DPI)") {
                        appState.currentPreset = ScanPreset.defaults[1]
                    }
                } label: {
                    Image(systemName: "doc.viewfinder")
                }
                .help("Quick Presets")

                Button {
                    Task {
                        if appState.scannerManager.connectionState.isConnected {
                            logger.info("Starting scan from toolbar")
                            await appState.startScanning()
                        } else if appState.useMockScanner {
                            logger.info("Connecting mock scanner from toolbar")
                            await appState.scannerManager.connectMockScanner()
                        }
                    }
                } label: {
                    Label(
                        appState.isScanning ? "Cancel Scan" : "Start Scan",
                        systemImage: appState.isScanning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner)
                .help("Start Scan (⌘R)")
            }
        }
    }
}

struct DetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .scan:
                ScanView()
            case .queue:
                QueueView()
            case .library:
                LibraryView()
            case .presets:
                PresetView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    MainWindow()
        .environment(AppState())
        .frame(width: 1000, height: 700)
}
#endif
