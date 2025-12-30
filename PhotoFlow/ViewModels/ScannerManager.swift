//
//  ScannerManager.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
#if os(macOS)
import ImageCaptureCore
import AppKit
#endif

enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected
    case scanning
    case error(String)

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Discovering..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .scanning: return "Scanning..."
        case .error(let message): return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        if case .scanning = self { return true }
        return false
    }
}

struct ScanResult {
    #if os(macOS)
    let image: NSImage
    #else
    let imageData: Data
    #endif
    let metadata: ScanMetadata
}

@Observable
class ScannerManager: NSObject {
    #if os(macOS)
    var availableScanners: [ICScannerDevice] = []
    var selectedScanner: ICScannerDevice?
    private var deviceBrowser: ICDeviceBrowser?
    #endif

    var connectionState: ConnectionState = .disconnected
    var lastError: String?
    var isScanning: Bool = false

    // Mock data for initial testing
    var mockScannerName: String = "Epson FastFoto FF-680W"
    var useMockScanner: Bool = true

    override init() {
        super.init()
        #if os(macOS)
        setupDeviceBrowser()
        #endif
    }

    #if os(macOS)
    private func setupDeviceBrowser() {
        deviceBrowser = ICDeviceBrowser()
        deviceBrowser?.delegate = self
        deviceBrowser?.browsedDeviceTypeMask = [.scanner]
    }

    func discoverScanners() async {
        connectionState = .discovering
        deviceBrowser?.start()

        // For mock mode, simulate discovery
        if useMockScanner {
            try? await Task.sleep(for: .seconds(1))
            connectionState = .disconnected
        }
    }

    func connect(to scanner: ICScannerDevice) async throws {
        connectionState = .connecting
        selectedScanner = scanner

        scanner.delegate = self
        scanner.requestOpenSession()

        // Wait for connection
        try await Task.sleep(for: .seconds(1))

        if scanner.hasOpenSession {
            connectionState = .connected
        } else {
            throw ScannerError.connectionFailed
        }
    }

    func connectMockScanner() async {
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
    }

    func disconnect() async {
        if let scanner = selectedScanner {
            scanner.requestCloseSession()
        }
        selectedScanner = nil
        connectionState = .disconnected
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        guard connectionState.isConnected || useMockScanner else {
            throw ScannerError.notConnected
        }

        connectionState = .scanning
        isScanning = true

        // Simulate scanning
        try await Task.sleep(for: .seconds(3))

        // Create mock result
        let mockImage = createMockImage()
        let metadata = ScanMetadata(
            resolution: preset.resolution,
            colorSpace: "sRGB",
            timestamp: Date(),
            scannerModel: mockScannerName
        )

        isScanning = false
        connectionState = .connected

        return ScanResult(image: mockImage, metadata: metadata)
    }

    func requestOverviewScan() async throws -> NSImage {
        guard connectionState.isConnected || useMockScanner else {
            throw ScannerError.notConnected
        }

        // Simulate preview scan
        try await Task.sleep(for: .seconds(1))
        return createMockImage()
    }

    private func createMockImage() -> NSImage {
        // Create a simple colored rectangle as mock scan
        let size = NSSize(width: 1200, height: 1600)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1.0).setFill()
            rect.fill()
            return true
        }
    }
    #else
    // iOS implementation stubs
    func discoverScanners() async {
        connectionState = .error("Scanner discovery not supported on iOS")
    }

    func connectMockScanner() async {
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
    }

    func disconnect() async {
        connectionState = .disconnected
    }
    #endif
}

#if os(macOS)
// MARK: - ICDeviceBrowserDelegate
extension ScannerManager: ICDeviceBrowserDelegate {
    func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        if let scanner = device as? ICScannerDevice {
            availableScanners.append(scanner)
            if !moreComing {
                connectionState = .disconnected
            }
        }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if let scanner = device as? ICScannerDevice {
            availableScanners.removeAll { $0 == scanner }
        }
    }

    func deviceBrowser(_ browser: ICDeviceBrowser, didEncounterError error: Error) {
        connectionState = .error(error.localizedDescription)
        lastError = error.localizedDescription
    }
}

// MARK: - ICScannerDeviceDelegate
extension ScannerManager: ICScannerDeviceDelegate {
    func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if let error = error {
            connectionState = .error(error.localizedDescription)
            lastError = error.localizedDescription
        } else {
            connectionState = .connected
        }
    }

    func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        connectionState = .disconnected
        selectedScanner = nil
    }

    func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        if let error = error {
            lastError = error.localizedDescription
        }
    }
}
#endif

enum ScannerError: LocalizedError {
    case notConnected
    case connectionFailed
    case scanFailed
    case noScannersFound

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Scanner is not connected"
        case .connectionFailed: return "Failed to connect to scanner"
        case .scanFailed: return "Scan operation failed"
        case .noScannersFound: return "No scanners found on network"
        }
    }
}
