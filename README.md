# PhotoFlow - Modern SwiftUI Scanner Interface

A native macOS scanning application built with SwiftUI featuring a beautiful, modern interface for controlling document and photo scanners.

## Features

### Phase 1: Foundation ✅ (Complete)
- SwiftUI-based macOS app with liquid glass material effects
- Navigation sidebar with 4 main sections
- Mock scanner integration for development
- Settings persistence with @AppStorage
- Preset management system
- Queue-based batch scanning workflow

## Project Structure

```
PhotoFlow/
├── PhotoFlow/
│   ├── PhotoFlowApp.swift         # Main app entry point
│   ├── Models/                     # Data models
│   │   ├── ScanPreset.swift
│   │   ├── ScannedFile.swift
│   │   ├── QueuedScan.swift
│   │   └── ScanMetadata.swift
│   ├── ViewModels/                 # State management
│   │   ├── AppState.swift
│   │   └── ScannerManager.swift
│   ├── Views/
│   │   ├── macOS/                  # macOS-specific views
│   │   │   ├── MainWindow.swift
│   │   │   ├── SidebarView.swift
│   │   │   └── SettingsView.swift
│   │   ├── iOS/                    # iOS views
│   │   │   └── ContentView.swift
│   │   └── Shared/                 # Cross-platform views
│   │       ├── ScanView.swift
│   │       ├── QueueView.swift
│   │       ├── LibraryView.swift
│   │       ├── PresetView.swift
│   │       └── Components/
│   │           ├── ScannerStatusView.swift
│   │           ├── PreviewView.swift
│   │           └── ControlPanelView.swift
│   └── Resources/
│       ├── Info-macOS.plist
│       └── Info-iOS.plist
├── PhotoFlow.xcodeproj/           # Xcode project
└── Package.swift                  # Swift Package Manager
```

## Requirements

- **macOS**: 14.0+ (Sonoma)
- **iOS**: 17.0+
- **Architecture**: Apple Silicon (arm64)
- **Xcode**: 15.0+
- **Swift**: 5.9+

## Getting Started

### Opening the Project

1. Clone the repository
2. Open `PhotoFlow.xcodeproj` in Xcode
3. Select the PhotoFlow scheme
4. Build and run (⌘R)

### First Launch

The app starts in "Mock Scanner" mode for testing without hardware:
1. Navigate to **Settings** (⌘,)
2. "Use mock scanner for testing" is enabled by default
3. Try scanning to see the full workflow

## Key Features

### 1. Scan View
- Live preview area (mock for now)
- Control panel with scan settings
- Preset selection
- Auto-enhancement toggles
- Configurable resolution and format

### 2. Scan Queue
- Add multiple scans to queue
- Batch processing
- Progress tracking
- Status indicators

### 3. Library
- Grid view of scanned files
- File metadata display
- Search and filter
- Quick Look integration

### 4. Presets
- Built-in presets:
  - Quick Scan (300 DPI JPEG)
  - Archive Quality (600 DPI TIFF)
  - Enlargement (1200 DPI)
  - Faded Photos Restoration
- Create custom presets
- Modify settings per preset

## Architecture

### State Management
Uses Swift's `@Observable` macro for reactive state management:
- `AppState`: Global app state
- `ScannerManager`: Scanner connection and operations

### Mock Scanner Mode
Currently uses mock scanner for development. Real scanner integration (Phase 2) will use:
- **ImageCaptureCore** framework on macOS
- Network discovery for Epson FastFoto FF-680W

### Design System
- **Materials**: `.ultraThinMaterial` for liquid glass effect
- **Typography**: SF Pro system font
- **Spacing**: 8pt grid system
- **Colors**: System adaptive with automatic dark mode

## Keyboard Shortcuts (macOS)

- `⌘R` - Start Scan
- `⌘,` - Settings
- `⌘1/2/3/4` - Navigate sections (coming soon)

## Next Steps (Upcoming Phases)

### Phase 2: Scanner Integration
- [ ] Real scanner discovery
- [ ] ImageCaptureCore integration
- [ ] Network scanner protocol
- [ ] Connection management

### Phase 3: Core Scanning
- [ ] Actual scanning workflow
- [ ] File saving with patterns
- [ ] Image processing pipeline
- [ ] Error handling

### Phase 4: Enhancement
- [ ] Color restoration (Core Image)
- [ ] Auto-rotate and deskew
- [ ] Red-eye removal
- [ ] OCR integration

### Phase 5: Polish
- [ ] All keyboard shortcuts
- [ ] Drag & drop support
- [ ] Quick Look integration
- [ ] Menu bar extra

### Phase 6: iOS Support
- [ ] iOS companion mode
- [ ] Remote scanner control
- [ ] File syncing

## Configuration

### Default Settings
Modify in Settings (⌘,):
- **Resolution**: 300/600/1200 DPI
- **Format**: JPEG/PNG/TIFF
- **Organization**: Single folder / By date / By month
- **Naming**: Custom pattern with date/number
- **Destination**: ~/Pictures/Scans

### Scan Destination
Default: `~/Pictures/Scans`
Files are organized based on your organization preference.

## Development

### Building
```bash
# Open in Xcode
open PhotoFlow.xcodeproj

# Or build from command line
xcodebuild -scheme PhotoFlow -configuration Debug

# Build for Release
xcodebuild -scheme PhotoFlow -configuration Release
```

### Mock Mode
Perfect for UI development without scanner hardware:
- Simulates connection delays
- Generates placeholder scans
- Tests full workflow

## License

Copyright © 2024. All rights reserved.

## Target Scanner

Primary target: **Epson FastFoto FF-680W**
- Network-connected photo scanner
- WiFi Direct support
- Batch photo scanning
- Fast scanning speeds

---

**Current Status**: Phase 1 Complete ✅
**Next Milestone**: Scanner Integration (Phase 2)
