//
//  ScanPreset.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

enum ScanFormat: String, Codable, CaseIterable {
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case png = "PNG"
}

enum DocumentType: String, Codable, CaseIterable {
    case photo = "Photo"
    case document = "Document"
    case polaroid = "Polaroid"
    case panoramic = "Panoramic"
}

struct ScanPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var resolution: Int // DPI
    var format: ScanFormat
    var quality: Double // 0-1
    var autoEnhance: Bool
    var restoreColor: Bool
    var removeRedEye: Bool
    var autoRotate: Bool
    var deskew: Bool
    var destination: String // Path as string for Codable
    var documentType: DocumentType

    init(
        id: UUID = UUID(),
        name: String,
        resolution: Int = 300,
        format: ScanFormat = .jpeg,
        quality: Double = 0.95,
        autoEnhance: Bool = true,
        restoreColor: Bool = false,
        removeRedEye: Bool = false,
        autoRotate: Bool = true,
        deskew: Bool = true,
        destination: String = "~/Pictures/Scans",
        documentType: DocumentType = .photo
    ) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.format = format
        self.quality = quality
        self.autoEnhance = autoEnhance
        self.restoreColor = restoreColor
        self.removeRedEye = removeRedEye
        self.autoRotate = autoRotate
        self.deskew = deskew
        self.destination = destination
        self.documentType = documentType
    }

    static let defaults: [ScanPreset] = [
        ScanPreset(
            name: "Quick Scan (300 DPI JPEG)",
            resolution: 300,
            format: .jpeg,
            quality: 0.90
        ),
        ScanPreset(
            name: "Archive Quality (600 DPI TIFF)",
            resolution: 600,
            format: .tiff,
            quality: 1.0,
            autoEnhance: false
        ),
        ScanPreset(
            name: "Enlargement (1200 DPI)",
            resolution: 1200,
            format: .tiff,
            quality: 1.0
        ),
        ScanPreset(
            name: "Faded Photos Restoration",
            resolution: 600,
            format: .jpeg,
            quality: 0.95,
            restoreColor: true,
            removeRedEye: true
        )
    ]

    static let quickScan = defaults[0]
}
