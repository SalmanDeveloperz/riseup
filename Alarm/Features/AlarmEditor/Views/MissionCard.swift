//
//  MissionCard.swift
//  RiseUp
//
//  LAYER: View (a card inside the Alarm Editor, #38)
//  WHAT:  "Wake-up mission", right under the time: an ON/OFF status, a strip of mission tiles
//         (one tap adds Math, Steps…), and the chosen missions (tap = adjust, − = remove).
//  VIEWMODEL: AlarmEditorViewModel (the same one as the editor; this card only reads it and calls it).
//
//  CONNECTIONS:
//    ← USED BY: AlarmEditorView.body (second card, after the time)
//    → TILE:    viewModel.quickAddMission(type) → added with defaults, or Mission Picker (Photo/QR, or to adjust)
//    → ROW:     viewModel.editMission / removeMission
//    → MORE:    viewModel.addMission() → the full Mission Picker (every mission, all settings)
//
//  WHY this card exists (the lead's UX review): missions are what makes RiseUp different, but the
//  old "Add mission" button sat below the fold, behind a sheet with two steps, so many people
//  never found it. Now it's the second thing you see, it says clearly whether the alarm is
//  protected, and the most common choice costs ONE tap.
//

import SwiftUI

struct MissionCard: View {
    let viewModel: AlarmEditorViewModel

    private var missions: [MissionDraft] { viewModel.draft.missions }

    var body: some View {
        GlowCard(isGlowing: true) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                header
                strip
                if !missions.isEmpty {
                    VStack(spacing: Theme.Spacing.xs) {
                        ForEach(missions) { mission in row(mission) }
                    }
                }
                moreButton
            }
        }
        .animation(.spring(duration: 0.35), value: missions)
        // LEARN: a short "tick" in the hand each time a mission is added or removed.
        .sensoryFeedback(.impact(weight: .light), trigger: missions.count)
    }

    // MARK: - Header: what this is, and whether the alarm is protected

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: missions.isEmpty ? "bolt.shield" : "bolt.shield.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.Gradients.brand)
                // LEARN: `.symbolEffect(.pulse)` gently breathes the icon: here only while the alarm has
                // NO mission, so the eye is drawn to the one thing still missing.
                .symbolEffect(.pulse, options: .repeating, isActive: missions.isEmpty)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wake-up mission")
                    .font(.riseHeadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(missions.isEmpty
                     ? "Pick one: the alarm won't stop until it's done."
                     : "Stops only after: \(missions.map(\.type.shortTitle).joined(separator: ", ")).")
                    .font(.riseCaption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            statusPill
        }
        .accessibilityElement(children: .combine)
    }

    /// "OFF" (grey) or "ON" (gradient): readable at a glance, like a switch.
    private var statusPill: some View {
        let isOn = !missions.isEmpty
        return Text(isOn ? "ON" : "OFF")
            .font(.caption.weight(.heavy))
            .tracking(0.5)
            .foregroundStyle(isOn ? Theme.Colors.onAccent : Theme.Colors.textTertiary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xxs)
            .background(isOn ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.surfaceRaised), in: .capsule)
            .contentTransition(.interpolate)
    }

    // MARK: - The strip of one-tap tiles

    private var strip: some View {
        // LEARN: a horizontal ScrollView lets 8 tiles live in one row. People know to swipe it when the
        // last visible tile is cut off at the edge, so the strip runs to the card's edges (found in the
        // Simulator: inside the card's padding exactly 4 tiles fitted, and nothing hinted at more).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(viewModel.quickMissionTypes) { type in tile(type) }
            }
            .padding(.vertical, Theme.Spacing.xs)               // room for the check badge and the glow
        }
        // LEARN: `contentMargins` indents the tiles (so the first one lines up with the title) while
        // the scrolling area itself reaches the card's edges (the negative padding).
        .contentMargins(.horizontal, Theme.Spacing.lg, for: .scrollContent)
        .padding(.horizontal, -Theme.Spacing.lg)
    }

    private func tile(_ type: MissionType) -> some View {
        let isChosen = viewModel.hasMission(type)
        let isEnabled = viewModel.isTileEnabled(type)

        return Button {
            viewModel.quickAddMission(type)                 // → added / adjusted / Mission Picker (Photo, QR)
        } label: {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: type.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isChosen ? AnyShapeStyle(Theme.Colors.onAccent) : AnyShapeStyle(Theme.Gradients.brand))
                    .frame(width: 56, height: 56)
                    .background {
                        RoundedRectangle(cornerRadius: Theme.Radius.chip, style: .continuous)
                            .fill(isChosen ? AnyShapeStyle(Theme.Gradients.brand) : AnyShapeStyle(Theme.Colors.surfaceRaised))
                    }
                    .overlay(alignment: .topTrailing) {
                        if isChosen {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.callout)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Theme.Colors.onAccent, Theme.Colors.accentDeep)
                                .offset(x: 6, y: -6)
                                .transition(.scale.combined(with: .opacity))
                        } else if type.needsSetup {
                            // Photo / QR: a small gear says "this one needs a quick setup".
                            Image(systemName: "gearshape.fill")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .offset(x: 3, y: -3)
                        }
                    }
                    .shadow(color: isChosen ? Theme.Colors.accent.opacity(0.45) : .clear, radius: 8, y: 3)

                VStack(spacing: 0) {
                    Text(type.shortTitle)
                        .font(.riseCaption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(type.tagline)
                        .font(.caption2)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .frame(width: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel("\(type.title) mission, \(type.tagline)")
        .accessibilityHint(isChosen ? "Adjust it" : type.needsSetup ? "Opens its setup" : "Adds it to this alarm")
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    // MARK: - The chosen missions

    private func row(_ mission: MissionDraft) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button {
                viewModel.editMission(mission)              // → Mission Picker, settings step
            } label: {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: mission.type.systemImage)
                        .font(.headline)
                        .foregroundStyle(Theme.Colors.onAccent)
                        .frame(width: 36, height: 36)
                        .background(Theme.Gradients.brand, in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.type.title).font(.riseHeadline).foregroundStyle(Theme.Colors.textPrimary)
                        Text(mission.summary).font(.riseCaption).foregroundStyle(Theme.Colors.textSecondary)
                    }
                    Spacer()
                    Text("Adjust")
                        .font(.riseCaption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accent)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Change difficulty and how many")

            Button {
                viewModel.removeMission(mission)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.Colors.danger)
                    .frame(width: 44, height: 44)             // a comfortable finger-sized target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(mission.type.title) mission")
        }
        .padding(.leading, Theme.Spacing.xs)
        .background(Theme.Colors.surfaceRaised.opacity(0.6), in: .rect(cornerRadius: Theme.Radius.chip, style: .continuous))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// "All missions & settings": the full picker (e.g. two Math missions, or a hard one from the start).
    @ViewBuilder
    private var moreButton: some View {
        if viewModel.canAddMission {
            Button {
                viewModel.addMission()                      // → coordinator → Mission Picker sheet
            } label: {
                Label(missions.isEmpty ? "All missions & settings" : "Add another mission",
                      systemImage: missions.isEmpty ? "slider.horizontal.3" : "plus.circle")
                    .font(.riseCaption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accent)
            }
            .buttonStyle(.plain)
        } else {
            Text("That's the most: \(AlarmEditorViewModel.maxMissions) missions per alarm.")
                .font(.riseCaption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }
}
