//
//  ThemeTests.swift
//  RiseUpTests
//
//  LAYER: Unit tests (Swift Testing) for themes (#35)
//  WHAT:  • Appearance is Dark by default, and System / Light / Dark map to the right colour scheme
//         • the appearance choice is saved
//         • picking a palette changes Theme.palette (every colour) and saves it for the widgets
//         • every palette is complete and different from the others
//  DATA:  a throwaway UserDefaults; the App Group value is put back afterwards.
//
//  CONNECTIONS:
//    → TESTS: AppearanceMode, ColorPalette, AppSettings.appearance / palette, ThemeStorage
//

import Foundation
import SwiftUI
import Testing
@testable import Alarm

@Suite("Themes", .serialized)
struct ThemeTests {
    private func freshSettings() -> AppSettings {
        AppSettings(store: UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!)
    }

    @Test("Dark by default; System follows the iPhone")
    func appearanceDefaults() {
        let settings = freshSettings()
        #expect(settings.appearance == .dark)
        #expect(AppearanceMode.system.colorScheme == nil)
        #expect(AppearanceMode.light.colorScheme == .light)
        #expect(AppearanceMode.dark.colorScheme == .dark)
    }

    @Test("The appearance choice is saved")
    func appearanceSaved() {
        let store = UserDefaults(suiteName: "RiseUpTests-\(UUID().uuidString)")!
        AppSettings(store: store).appearance = .light
        #expect(AppSettings(store: store).appearance == .light)
    }

    @Test("Picking a palette recolours the app and is saved for the widgets")
    func paletteChange() {
        let before = Theme.palette
        defer { freshSettings().palette = before }              // leave the app as it was

        let settings = freshSettings()
        settings.palette = .ocean
        #expect(Theme.palette == .ocean)
        #expect(ThemeStorage.loadPalette() == .ocean)
    }

    @Test("Every palette has four different accents, and no two palettes share a main accent")
    func palettesComplete() {
        for palette in ColorPalette.allCases {
            #expect(Set([palette.accent, palette.accentDeep, palette.accentWarm, palette.accentCool]).count == 4, "\(palette)")
        }
        #expect(Set(ColorPalette.allCases.map(\.accent)).count == ColorPalette.allCases.count)
    }
}
