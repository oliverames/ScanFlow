//
//  ScannerManager.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import os.log
#if os(macOS)
import ImageCaptureCore
import AppKit
#endif

/// Logging subsystem for ScanFlow
private let logger = Logger(subsystem: "com.scanflow.app", category: "ScannerManager")

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
@MainActor
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
    var useMockScanner: Bool = false

    override init() {
        super.init()
        #if os(macOS)
        setupDeviceBrowser()
        #endif
    }

    #if os(macOS)
    private func setupDeviceBrowser() {
        print("🔧 [ScannerManager] Setting up device browser...")
        logger.info("Setting up device browser for scanner discovery")

        deviceBrowser = ICDeviceBrowser()
        deviceBrowser?.delegate = self

        // Include all scanner location types: local (USB), shared (network), bonjour, bluetooth
        // The mask combines device type with location types
        let scannerTypeMask = ICDeviceTypeMask.scanner.rawValue
        let localMask = ICDeviceLocationTypeMask.local.rawValue
        let sharedMask = ICDeviceLocationTypeMask.shared.rawValue
        let bonjourMask = ICDeviceLocationTypeMask.bonjour.rawValue
        let bluetoothMask = ICDeviceLocationTypeMask.bluetooth.rawValue

        let combinedMask = scannerTypeMask | localMask | sharedMask | bonjourMask | bluetoothMask
        print("🔧 [ScannerManager] Combined device mask: \(combinedMask) (scanner=\(scannerTypeMask), local=\(localMask), shared=\(sharedMask), bonjour=\(bonjourMask), bluetooth=\(bluetoothMask))")

        if let mask = ICDeviceTypeMask(rawValue: combinedMask) {
            deviceBrowser?.browsedDeviceTypeMask = mask
            print("🔧 [ScannerManager] Device browser mask set successfully")
        } else {
            print("❌ [ScannerManager] Failed to create device type mask!")
        }

        print("🔧 [ScannerManager] Device browser delegate: \(String(describing: deviceBrowser?.delegate))")
        logger.info("Device browser configured for local, shared, bonjour, and bluetooth scanners (mask: \(combinedMask))")
    }

    func discoverScanners() async {
        print("🔍 [ScannerManager] discoverScanners() called")
        logger.info("Starting scanner discovery...")

        // Only change to discovering state if we're not already connected
        if !connectionState.isConnected {
            connectionState = .discovering
        }

        // Ensure device browser is set up
        if deviceBrowser == nil {
            print("⚠️ [ScannerManager] Device browser was nil, setting up again")
            logger.warning("Device browser was nil, setting up again")
            setupDeviceBrowser()
        }

        // Start browsing if not already
        let isBrowsing = deviceBrowser?.isBrowsing ?? false
        if !isBrowsing {
            print("🔍 [ScannerManager] Starting device browser...")
            deviceBrowser?.start()
        } else {
            print("🔍 [ScannerManager] Device browser already running")
        }

        // Wait for discovery - delegates will populate the list
        print("🔍 [ScannerManager] Waiting 3 seconds for scanner discovery...")
        try? await Task.sleep(for: .seconds(3))

        // Log results
        print("🔍 [ScannerManager] Discovery complete. Found \(self.availableScanners.count) scanner(s)")
        logger.info("Discovery complete. Found \(self.availableScanners.count) scanner(s)")

        for scanner in availableScanners {
            print("✅ [ScannerManager] Available: \(scanner.name ?? "Unknown")")
        }

        // Only set to disconnected if we're still in discovering state
        if case .discovering = connectionState {
            connectionState = .disconnected
        }
    }

    /// Start continuous browsing - call once at app launch
    func startBrowsing() {
        print("🔍 [ScannerManager] startBrowsing() called")
        if deviceBrowser == nil {
            setupDeviceBrowser()
        }
        if !(deviceBrowser?.isBrowsing ?? false) {
            print("🔍 [ScannerManager] Starting device browser...")
            deviceBrowser?.start()
            print("🔍 [ScannerManager] Device browser started, isBrowsing: \(deviceBrowser?.isBrowsing ?? false)")
        }
    }

    /// Stop browsing
    func stopBrowsing() {
        print("🔍 [ScannerManager] stopBrowsing() called")
        deviceBrowser?.stop()
    }

    func connect(to scanner: ICScannerDevice) async throws {
        print("🔌 [ScannerManager] Connecting to scanner: \(scanner.name ?? "Unknown")")
        print("🔌 [ScannerManager] Scanner type: \(scanner.usbLocationID != 0 ? "USB" : "Network")")
        logger.info("Connecting to scanner: \(scanner.name ?? "Unknown")")
        connectionState = .connecting
        selectedScanner = scanner

        scanner.delegate = self

        print("🔌 [ScannerManager] Scanner hasOpenSession before: \(scanner.hasOpenSession)")

        // If already has open session, we're good
        if scanner.hasOpenSession {
            print("✅ [ScannerManager] Scanner already has open session!")
            connectionState = .connected
            return
        }

        print("🔌 [ScannerManager] Requesting open session...")
        logger.info("Requesting open session...")

        // Try up to 3 times with delays
        var lastError: Error?
        for attempt in 1...3 {
            print("🔌 [ScannerManager] Connection attempt \(attempt)/3...")

            do {
                // Use continuation with timeout to properly wait for the delegate callback
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            Task { @MainActor in
                                self.connectionContinuation = continuation
                                // Request open session - the result comes via delegate callback
                                scanner.requestOpenSession()
                            }
                        }
                    }

                    group.addTask {
                        // Timeout after 15 seconds
                        try await Task.sleep(for: .seconds(15))
                        throw ScannerError.connectionFailed
                    }

                    // Wait for either connection success or timeout
                    try await group.next()
                    group.cancelAll()
                }

                print("✅ [ScannerManager] Successfully connected on attempt \(attempt)!")
                logger.info("Successfully connected to scanner")
                connectionState = .connected
                return

            } catch {
                print("❌ [ScannerManager] Attempt \(attempt) failed: \(error)")
                lastError = error
                connectionContinuation = nil

                if attempt < 3 {
                    print("🔌 [ScannerManager] Waiting 3 seconds before retry...")
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        }

        // All attempts failed
        print("❌ [ScannerManager] All connection attempts failed")
        logger.error("Failed to connect after 3 attempts: \(lastError?.localizedDescription ?? "unknown error")")
        connectionState = .error(lastError?.localizedDescription ?? "Connection failed")
        selectedScanner = nil
        throw lastError ?? ScannerError.connectionFailed
    }

    func connectMockScanner() async {
        logger.info("Connecting to mock scanner...")
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
        logger.info("Mock scanner connected")
    }

    func disconnect() async {
        if let scanner = selectedScanner {
            try? await scanner.requestCloseSession()
        }
        selectedScanner = nil
        connectionState = .disconnected
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        print("📷 [ScannerManager] scan() called with preset: \(preset.name)")
        logger.info("Starting scan with preset: \(preset.name)")

        guard connectionState.isConnected || useMockScanner else {
            print("❌ [ScannerManager] Not connected!")
            throw ScannerError.notConnected
        }

        connectionState = .scanning
        isScanning = true

        defer {
            isScanning = false
            connectionState = .connected
        }

        // Use mock scanner if enabled
        if useMockScanner {
            print("📷 [ScannerManager] Using mock scanner")
            try await Task.sleep(for: .seconds(3))
            let mockImage = createMockImage()
            let metadata = ScanMetadata(
                resolution: preset.resolution,
                colorSpace: "sRGB",
                timestamp: Date(),
                scannerModel: mockScannerName,
                width: Int(mockImage.size.width),
                height: Int(mockImage.size.height),
                bitDepth: 8
            )
            return ScanResult(image: mockImage, metadata: metadata)
        }

        // Real scanner workflow
        guard let scanner = selectedScanner else {
            print("❌ [ScannerManager] No scanner selected!")
            throw ScannerError.notConnected
        }

        print("📷 [ScannerManager] Scanner: \(scanner.name ?? "Unknown")")
        print("📷 [ScannerManager] Has open session: \(scanner.hasOpenSession)")

        // Set up transfer mode - file-based to get scanned images as files
        scanner.transferMode = .fileBased
        print("📷 [ScannerManager] Transfer mode set to file-based")

        // Set downloads directory
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("ScanFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        scanner.downloadsDirectory = tempDir
        print("📷 [ScannerManager] Downloads directory: \(tempDir.path)")

        // Check available functional units
        print("📷 [ScannerManager] Available functional units: \(scanner.availableFunctionalUnitTypes)")

        // Get functional unit
        var selectedUnit = scanner.selectedFunctionalUnit
        print("📷 [ScannerManager] Initial functional unit type: \(selectedUnit.type.rawValue)")
        print("📷 [ScannerManager] Supported resolutions: \(selectedUnit.supportedResolutions)")

        // If functional unit has no supported resolutions, try to select a different one
        if selectedUnit.supportedResolutions.isEmpty {
            print("⚠️ [ScannerManager] Functional unit has no supported resolutions, selecting a new one...")

            // Try to select a functional unit that supports scanning
            if scanner.availableFunctionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue)) {
                print("📷 [ScannerManager] Requesting document feeder...")
                scanner.requestSelect(ICScannerFunctionalUnitType.documentFeeder)
            } else if scanner.availableFunctionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue)) {
                print("📷 [ScannerManager] Requesting flatbed...")
                scanner.requestSelect(ICScannerFunctionalUnitType.flatbed)
            }

            // Wait for selection
            try await Task.sleep(for: .seconds(2))
            selectedUnit = scanner.selectedFunctionalUnit
            print("📷 [ScannerManager] After selection - type: \(selectedUnit.type.rawValue), resolutions: \(selectedUnit.supportedResolutions)")

            if selectedUnit.supportedResolutions.isEmpty {
                print("❌ [ScannerManager] Still no valid functional unit after selection!")
                throw ScannerError.scanFailed
            }
        }
        print("📷 [ScannerManager] Functional unit type: \(selectedUnit.type.rawValue)")
        print("📷 [ScannerManager] Supported resolutions: \(selectedUnit.supportedResolutions)")

        // Apply preset settings to scanner
        configureScannerSettings(selectedUnit, with: preset)

        print("📷 [ScannerManager] Requesting scan...")
        logger.info("Requesting scan from scanner")

        // Perform the scan
        return try await withCheckedThrowingContinuation { continuation in
            currentScanContinuation = continuation
            scanner.requestScan()
            print("📷 [ScannerManager] requestScan() called, waiting for delegate callback...")
        }
    }

    private func configureScannerSettings(_ functionalUnit: ICScannerFunctionalUnit, with preset: ScanPreset) {
        // Set resolution
        if functionalUnit.supportedResolutions.contains(preset.resolution) {
            functionalUnit.resolution = preset.resolution
        }

        // Configure document feeder if available
        if let documentFeeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            documentFeeder.documentType = .typeDefault

            // Enable duplex if requested and supported
            if preset.useDuplex && documentFeeder.supportsDuplexScanning {
                documentFeeder.duplexScanningEnabled = true
            } else {
                documentFeeder.duplexScanningEnabled = false
            }

            // Enable document feeder mode
            if preset.useADF {
                documentFeeder.documentType = .typeDefault
            }
        }

        // Set scan area to maximum
        let physicalSize = functionalUnit.physicalSize
        functionalUnit.scanArea = NSRect(origin: .zero, size: physicalSize)

        // Set pixel data type based on preset
        if preset.documentType == .document {
            functionalUnit.pixelDataType = .BW // Black & white for documents
        } else {
            functionalUnit.pixelDataType = .RGB // Color for photos
        }
    }

    // Store continuation for async scanning
    private var currentScanContinuation: CheckedContinuation<ScanResult, Error>?

    // Store continuation for async connection
    private var connectionContinuation: CheckedContinuation<Void, Error>?

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
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        // Log ALL devices found for debugging
        let deviceType = device is ICScannerDevice ? "SCANNER" : "OTHER"
        let locationDesc: String
        if device.usbLocationID != 0 {
            locationDesc = "USB"
        } else {
            locationDesc = "Network/Shared"
        }

        print("🔍 [ICDeviceBrowser] Device found: \(device.name ?? "Unknown") | Type: \(deviceType) | Location: \(locationDesc) | moreComing: \(moreComing)")

        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("✅ Scanner found: \(scanner.name ?? "Unknown"), location: \(locationDesc)")
                print("✅ Adding scanner to list: \(scanner.name ?? "Unknown")")
                if !self.availableScanners.contains(scanner) {
                    self.availableScanners.append(scanner)
                }
                if !moreComing {
                    logger.info("Scanner discovery batch complete, found \(self.availableScanners.count) scanner(s)")
                    self.connectionState = .disconnected
                }
            }
        } else {
            print("⚠️ Device is not a scanner: \(device.name ?? "Unknown")")
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        print("🗑️ [ICDeviceBrowser] Device removed: \(device.name ?? "Unknown")")
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("Scanner removed: \(scanner.name ?? "Unknown")")
                self.availableScanners.removeAll { $0 == scanner }
            }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didEncounterError error: Error) {
        print("❌ [ICDeviceBrowser] Error: \(error.localizedDescription)")
        Task { @MainActor in
            logger.error("Device browser error: \(error.localizedDescription)")
            self.connectionState = .error(error.localizedDescription)
            self.lastError = error.localizedDescription
        }
    }

    nonisolated func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        print("📋 [ICDeviceBrowser] Finished enumerating LOCAL devices")
    }
}

// MARK: - ICScannerDeviceDelegate
extension ScannerManager: ICScannerDeviceDelegate {
    nonisolated func didRemove(_ device: ICDevice) {
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                if scanner == selectedScanner {
                    selectedScanner = nil
                    connectionState = .disconnected
                }
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        print("🔌 [ScannerManager] didOpenSessionWithError called, error: \(error?.localizedDescription ?? "none")")
        Task { @MainActor in
            // Resume the connection continuation if we have one
            if let continuation = self.connectionContinuation {
                self.connectionContinuation = nil
                if let error = error {
                    print("❌ [ScannerManager] Session open failed: \(error.localizedDescription)")
                    connectionState = .error(error.localizedDescription)
                    lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                } else {
                    print("✅ [ScannerManager] Session opened successfully via delegate!")
                    connectionState = .connected
                    continuation.resume()
                }
            } else {
                // No continuation, just update state directly
                if let error = error {
                    connectionState = .error(error.localizedDescription)
                    lastError = error.localizedDescription
                } else {
                    connectionState = .connected
                }
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
            selectedScanner = nil
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        print("📷 [ScannerManager] didSelect functionalUnit: \(functionalUnit.type.rawValue), error: \(error?.localizedDescription ?? "none")")
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        print("📷 [ScannerManager] didScanTo URL: \(url.path)")
        // Image was scanned successfully
        Task { @MainActor in
            guard let continuation = currentScanContinuation else {
                print("⚠️ [ScannerManager] No scan continuation to resume!")
                return
            }
            currentScanContinuation = nil

            do {
                print("📷 [ScannerManager] Loading image from: \(url.path)")
                guard let image = NSImage(contentsOf: url) else {
                    print("❌ [ScannerManager] Failed to load image from URL")
                    continuation.resume(throwing: ScannerError.scanFailed)
                    return
                }

                print("📷 [ScannerManager] Image loaded, size: \(image.size)")
                let metadata = ScanMetadata(
                    resolution: scanner.selectedFunctionalUnit.resolution,
                    colorSpace: "sRGB",
                    timestamp: Date(),
                    scannerModel: scanner.name ?? "Unknown Scanner",
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    bitDepth: scanner.selectedFunctionalUnit.pixelDataType == .BW ? 1 : 8
                )

                let result = ScanResult(image: image, metadata: metadata)
                print("✅ [ScannerManager] Scan completed successfully!")
                continuation.resume(returning: result)

                // Clean up temporary file
                try? FileManager.default.removeItem(at: url)
            } catch {
                print("❌ [ScannerManager] Error processing scan: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didCompleteOverviewScanWithError error: Error?) {
        print("📷 [ScannerManager] didCompleteOverviewScanWithError: \(error?.localizedDescription ?? "none")")
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        print("📷 [ScannerManager] didCompleteScanWithError: \(error?.localizedDescription ?? "none")")
        Task { @MainActor in
            guard let continuation = currentScanContinuation else {
                print("⚠️ [ScannerManager] No scan continuation for completion")
                return
            }
            currentScanContinuation = nil

            if let error = error {
                print("❌ [ScannerManager] Scan failed: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            } else {
                print("✅ [ScannerManager] Scan completed without error")
            }
        }
    }

    // Additional scan delegate methods for progress
    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didScanTo data: ICScannerBandData) {
        print("📷 [ScannerManager] didScanTo data band: \(data.dataSize) bytes")
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
