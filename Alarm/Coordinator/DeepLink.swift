//
//  DeepLink.swift
//  RiseUp
//
//  LAYER: Coordinator (pure value type)
//  WHAT:  The `riseup://…` links the widgets open, turned into something the coordinator understands:
//           riseup://new             → a new alarm in the editor
//           riseup://alarm/<UUID>    → that alarm in the editor
//           riseup://nap/<minutes>   → the Quick Alarm sheet, set to that many minutes
//  DATA:  none.
//
//  CONNECTIONS:
//    ← CREATED BY: RootView `.onOpenURL` (iOS opens RiseUp with the link)
//    ← LINKS MADE BY: Shared/WidgetSnapshot.swift (`WidgetShared.newAlarmURL` …), used by the widgets
//    → HANDLED BY: AppCoordinator.open(_:)
//
//  LEARN: a "URL scheme" is like a private web address for an app. `riseup` is registered in
//  Config/Info.plist (CFBundleURLTypes), so iOS knows that `riseup://…` means "open RiseUp".
//

import Foundation

nonisolated enum DeepLink: Equatable {
    case newAlarm
    case alarm(UUID)
    case nap(minutes: Int)

    /// nil for anything we don't recognise (a typo, an old link): then nothing happens.
    init?(url: URL) {
        guard url.scheme == "riseup" else { return nil }
        // LEARN: in "riseup://alarm/1234", "alarm" is the HOST and "/1234" the PATH.
        let value = url.pathComponents.dropFirst().first        // pathComponents = ["/", "1234"]
        switch url.host() {
        case "new":
            self = .newAlarm
        case "alarm":
            guard let value, let id = UUID(uuidString: value) else { return nil }
            self = .alarm(id)
        case "nap":
            guard let value, let minutes = Int(value), (1...720).contains(minutes) else { return nil }
            self = .nap(minutes: minutes)
        default:
            return nil
        }
    }
}
