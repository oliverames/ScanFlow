//
//  ScannerStatusView.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import SwiftUI

struct ScannerStatusView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay {
                    if appState.scannerManager.connectionState == .scanning {
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: 16, height: 16)
                            .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    }
                }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
    }

    @State private var pulseAnimation = false

    private var statusColor: Color {
        switch appState.scannerManager.connectionState {
        case .connected, .scanning:
            return .green
        case .connecting, .discovering:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }

    private var statusText: String {
        if appState.useMockScanner {
            return "Mock Scanner"
        }
        return appState.scannerManager.connectionState.description
    }

    private var animationTimer: Timer {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                pulseAnimation.toggle()
            }
        }
    }
}

#Preview {
    HStack {
        ScannerStatusView()
            .environment(AppState())
    }
    .padding()
}
