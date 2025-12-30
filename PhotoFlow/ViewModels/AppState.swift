//
//  AppState.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import SwiftUI

enum NavigationSection: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case queue = "Scan Queue"
    case library = "Scanned Files"
    case presets = "Scan Presets"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .scan: return "scanner"
        case .queue: return "list.bullet"
        case .library: return "photo.stack"
        case .presets: return "slider.horizontal.3"
        }
    }
}

@Observable
class AppState {
    var scannerManager = ScannerManager()
    var scanQueue: [QueuedScan] = []
    var scannedFiles: [ScannedFile] = []
    var presets: [ScanPreset] = ScanPreset.defaults
    var currentPreset: ScanPreset = ScanPreset.quickScan
    var selectedSection: NavigationSection = .scan
    var isScanning: Bool = false
    var showingAlert: Bool = false
    var alertMessage: String = ""

    // Settings
    @AppStorage("defaultResolution") var defaultResolution: Int = 300
    @AppStorage("defaultFormat") var defaultFormat: String = "jpeg"
    @AppStorage("scanDestination") var scanDestination: String = "~/Pictures/Scans"
    @AppStorage("autoOpenDestination") var autoOpenDestination: Bool = true
    @AppStorage("organizationPattern") var organizationPattern: String = "date"
    @AppStorage("fileNamingTemplate") var fileNamingTemplate: String = "yyyy-MM-dd_###"
    @AppStorage("useMockScanner") var useMockScanner: Bool = true

    init() {
        // Initialize with user defaults if needed
        loadPresets()
    }

    func loadPresets() {
        // Load custom presets from UserDefaults if available
        if let data = UserDefaults.standard.data(forKey: "customPresets"),
           let customPresets = try? JSONDecoder().decode([ScanPreset].self, from: data) {
            presets = ScanPreset.defaults + customPresets
        }
    }

    func savePresets() {
        let customPresets = presets.filter { preset in
            !ScanPreset.defaults.contains { $0.id == preset.id }
        }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "customPresets")
        }
    }

    func addToQueue(preset: ScanPreset, count: Int = 1) {
        for i in 0..<count {
            let scan = QueuedScan(
                name: "Scan \(scanQueue.count + i + 1)",
                preset: preset
            )
            scanQueue.append(scan)
        }
    }

    func removeFromQueue(scan: QueuedScan) {
        scanQueue.removeAll { $0.id == scan.id }
    }

    func startScanning() async {
        guard !scanQueue.isEmpty else { return }
        isScanning = true

        for index in scanQueue.indices where scanQueue[index].status == .pending {
            scanQueue[index].status = .scanning

            do {
                #if os(macOS)
                let result = try await scannerManager.scan(with: scanQueue[index].preset)

                // Save the scanned file
                scanQueue[index].status = .processing
                let savedFile = try await saveScannedImage(result, preset: scanQueue[index].preset)
                scannedFiles.append(savedFile)

                scanQueue[index].status = .completed
                #endif
            } catch {
                scanQueue[index].status = .failed(error.localizedDescription)
                showAlert(message: "Scan failed: \(error.localizedDescription)")
            }
        }

        isScanning = false
    }

    #if os(macOS)
    private func saveScannedImage(_ result: ScanResult, preset: ScanPreset) async throws -> ScannedFile {
        // Expand tilde in path
        let destPath = NSString(string: preset.destination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        // Generate filename
        let filename = generateFilename(format: preset.format)
        let fileURL = destURL.appendingPathComponent(filename)

        // Save image
        guard let tiffData = result.image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            throw ScannerError.scanFailed
        }

        let imageData: Data?
        switch preset.format {
        case .jpeg:
            imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality])
        case .png:
            imageData = bitmapImage.representation(using: .png, properties: [:])
        case .tiff:
            imageData = tiffData
        }

        guard let data = imageData else {
            throw ScannerError.scanFailed
        }

        try data.write(to: fileURL)

        return ScannedFile(
            filename: filename,
            fileURL: fileURL,
            size: Int64(data.count),
            resolution: result.metadata.resolution,
            dateScanned: result.metadata.timestamp,
            scannerModel: result.metadata.scannerModel,
            format: preset.format
        )
    }
    #endif

    private func generateFilename(format: ScanFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        // Find next available number
        var counter = 1
        var filename = "\(dateString)_\(String(format: "%03d", counter)).\(format.rawValue.lowercased())"

        let destPath = NSString(string: scanDestination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        while FileManager.default.fileExists(atPath: destURL.appendingPathComponent(filename).path) {
            counter += 1
            filename = "\(dateString)_\(String(format: "%03d", counter)).\(format.rawValue.lowercased())"
        }

        return filename
    }

    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}
