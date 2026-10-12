//
//  BarcodeScanScreen.swift
//  RiseUp
//
//  LAYER: View (reusable capture piece: SwiftUI ↔ UIKit bridge)
//  WHAT:  A full-screen live camera that reads the first QR code or barcode it sees.
//         In the Simulator (no camera) it shows a text field to type a code instead.
//  DATA:  none stored. Hands the code's text back through `onCode`.
//
//  CONNECTIONS:
//    ← USED BY: MissionPickerView (register a code), BarcodeMissionView (scan it in the morning)
//    → USES:    VisionKit DataScannerViewController (live camera + barcode reading)
//
//  LEARN: DataScannerViewController (VisionKit) does all the hard work: it runs the camera,
//  finds codes in each frame, and highlights them. We only listen for "a new code appeared".
//

import SwiftUI
import VisionKit

struct BarcodeScanScreen: View {
    let title: String
    let onCode: (String) -> Void
    let onCancel: () -> Void

    @State private var typedCode = ""

    /// True when this iPhone can scan (real camera present + allowed + supported chip).
    static var canScan: Bool {
        CameraAccess.usesRealCamera && DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ZStack {
            if Self.canScan {
                BarcodeScannerView(onCode: onCode)
                    .ignoresSafeArea()
            } else {
                AppBackground()
            }

            VStack(spacing: Theme.Spacing.md) {
                Text(title)
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(Theme.Spacing.md)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.card, style: .continuous))

                Spacer()

                if !Self.canScan && MissionEnvironment.isSimulator {
                    simulatorInput
                }

                Button("Cancel", action: onCancel)
                    .buttonStyle(.ghost)
            }
            .padding(Theme.Spacing.lg)
        }
    }

    /// Simulator only: type any text and pretend it was scanned.
    private var simulatorInput: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("No camera in the Simulator. Type a code to test:")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                TextField("e.g. RISEUP-123", text: $typedCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .foregroundStyle(Theme.Colors.textPrimary)
                Button("Use this code") { onCode(typedCode.trimmingCharacters(in: .whitespaces)) }
                    .buttonStyle(.neon)
                    .disabled(typedCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

/// VisionKit's live scanner, wrapped for SwiftUI.
private struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],      // every kind: QR, EAN (food packs), Code 128…
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,  // saves battery; we only need one read
            isHighlightingEnabled: true             // draws a box around the code it found
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        // WHY here and not in make…: scanning can only start once the screen is on display.
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    /// LEARN: SwiftUI calls this when the scanner leaves the screen: stop the camera.
    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        /// VisionKit: "these items just appeared in the camera view".
        func dataScanner(_ dataScanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                // LEARN: `if case .barcode(let code) = item` = "if this item is a barcode, call it `code`".
                if case .barcode(let code) = item, let text = code.payloadStringValue, !text.isEmpty {
                    onCode(text)
                    return
                }
            }
        }
    }
}

#Preview {
    BarcodeScanScreen(title: "Scan the code on your toothpaste", onCode: { _ in }, onCancel: {})
}
