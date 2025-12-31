//
//  ControlPanelView.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI
import os.log
#if os(macOS)
import ImageCaptureCore
#endif

private let logger = Logger(subsystem: "com.scanflow.app", category: "ControlPanelView")

struct ControlPanelView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Current Preset
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Preset")
                            .font(.headline)
                            .lineLimit(1)

                        Menu {
                            ForEach(appState.presets) { preset in
                                Button(preset.name) {
                                    logger.info("Preset changed to: \(preset.name)")
                                    appState.currentPreset = preset
                                }
                            }
                        } label: {
                            HStack {
                                Text(appState.currentPreset.name)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()

                    // Scan Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Scan Settings")
                            .font(.headline)
                            .lineLimit(1)

                        // Document Type
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Document Type")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Picker("", selection: $appState.currentPreset.documentType) {
                                ForEach(DocumentType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Resolution
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Resolution")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(appState.currentPreset.resolution) DPI")
                                    .font(.subheadline)
                                    .monospacedDigit()
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(appState.currentPreset.resolution) },
                                    set: { appState.currentPreset.resolution = Int($0) }
                                ),
                                in: 300...1200,
                                step: 300
                            )
                        }

                        // Format
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Format")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            HStack {
                                Picker("", selection: $appState.currentPreset.format) {
                                    ForEach(ScanFormat.allCases, id: \.self) { format in
                                        Text(format.rawValue).tag(format)
                                    }
                                }
                                .labelsHidden()
                                .fixedSize()

                                if appState.currentPreset.format == .jpeg {
                                    Spacer()
                                    Text("Quality:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(appState.currentPreset.quality * 100))%")
                                        .font(.caption)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    Divider()

                    // Auto-Enhancement
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Enhancement")
                            .font(.headline)
                            .lineLimit(1)

                        Toggle("Restore Faded Colors", isOn: $appState.currentPreset.restoreColor)
                            .lineLimit(1)
                        Toggle("Remove Red-Eye", isOn: $appState.currentPreset.removeRedEye)
                            .lineLimit(1)
                        Toggle("Auto Rotate", isOn: $appState.currentPreset.autoRotate)
                            .lineLimit(1)
                        Toggle("Deskew", isOn: $appState.currentPreset.deskew)
                            .lineLimit(1)
                    }
                    .toggleStyle(.switch)

                    Divider()

                    // Destination
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Destination")
                                .font(.headline)
                        } icon: {
                            Image(systemName: "folder")
                        }
                        .lineLimit(1)

                        TextField("", text: $appState.currentPreset.destination)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .truncationMode(.middle)
                    }

                    // Scan Button
                    Button {
                        logger.info("Scan button pressed")
                        Task {
                            appState.addToQueue(preset: appState.currentPreset, count: 1)
                            await appState.startScanning()
                        }
                    } label: {
                        Label(
                            appState.isScanning ? "Scanning..." : "Scan",
                            systemImage: appState.isScanning ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appState.isScanning || (!appState.scannerManager.connectionState.isConnected && !appState.useMockScanner))
                }
                .padding()
            }
        }
        .frame(width: 280)
        .clipped()
    }
}

#Preview {
    ControlPanelView()
        .environment(AppState())
        .frame(width: 320, height: 800)
}
