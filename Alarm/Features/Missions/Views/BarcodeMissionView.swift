//
//  BarcodeMissionView.swift
//  RiseUp
//
//  LAYER: View (Mission 15h: QR / Barcode)
//  WHAT:  "Scan your code" with a big button that opens the live scanner, and the result.
//  VIEWMODEL: BarcodeMissionViewModel.
//
//  CONNECTIONS:
//    ← BUILT BY: MissionView (for missions of type .barcode)
//    → PRESENTS: BarcodeScanScreen (full screen camera)
//

import SwiftUI

struct BarcodeMissionView: View {
    @State private var viewModel: BarcodeMissionViewModel

    init(viewModel: BarcodeMissionViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            MissionProgressHeader(type: .barcode, done: viewModel.status == .matched ? 1 : 0, total: 1)

            Spacer(minLength: 0)

            Image(systemName: viewModel.status == .matched ? "checkmark.circle.fill" : "qrcode.viewfinder")
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(viewModel.status == .matched ? AnyShapeStyle(Theme.Gradients.success) : AnyShapeStyle(Theme.Gradients.sunrise))
                .contentTransition(.symbolEffect(.replace))
                .shadow(color: Theme.Colors.neonPink.opacity(0.5), radius: 24)

            VStack(spacing: Theme.Spacing.xs) {
                Text("Walk to your code and scan it")
                    .font(.riseTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                statusText
            }

            Spacer(minLength: 0)

            Button {
                Task { await viewModel.openScanner() }     // → permission → scanner
            } label: {
                Label(viewModel.status == .wrongCode ? "Scan again" : "Scan code", systemImage: "qrcode.viewfinder")
            }
            .buttonStyle(.neon)
            .disabled(viewModel.status == .matched)

            if viewModel.canGiveUp {
                Button("Can't find it? Do 5 hard maths problems instead") { viewModel.giveUp() }
                    .buttonStyle(.ghost)
            }
        }
        .onAppear { viewModel.start() }
        .fullScreenCover(isPresented: $viewModel.isShowingScanner) {
            BarcodeScanScreen(
                title: "Point the camera at your registered code",
                onCode: { viewModel.scanned($0) },        // → right or wrong code
                onCancel: { viewModel.isShowingScanner = false }
            )
        }
        .animation(.spring(duration: 0.3), value: viewModel.status)
        .sensoryFeedback(.success, trigger: viewModel.status == .matched)
        .sensoryFeedback(.error, trigger: viewModel.wrongScans)
    }

    @ViewBuilder
    private var statusText: some View {
        switch viewModel.status {
        case .ready:
            Text("The same QR code or barcode you registered.")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textSecondary)
        case .wrongCode:
            Text("That's a different code. Find the registered one!")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.danger)
                .multilineTextAlignment(.center)
        case .matched:
            Text("Got it. Good morning!")
                .font(.riseHeadline)
                .foregroundStyle(Theme.Colors.success)
        }
    }
}

#Preview {
    BarcodeMissionView(viewModel: BarcodeMissionViewModel(
        mission: MissionDraft(type: .barcode, difficulty: .normal, repetitions: 1, textPayload: "RISEUP-123"),
        onInteraction: {}, onComplete: {}
    ))
    .padding()
    .appBackground()
}
