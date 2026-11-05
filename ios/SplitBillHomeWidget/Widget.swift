// Shared model, timeline provider, theme and App Intent for the Evens
// widgets. All amounts and labels are computed, localized and formatted in
// Dart (lib/services/home_widget_data.dart) and arrive as one JSON payload in
// the App Group, so this file only decodes and displays.

import AppIntents
import SwiftUI
import WidgetKit

enum SplitBillHomeWidgetFlavor {
  static let appGroupId = "group.com.example.splitBillApp.widgets"
  /// Written by Flutter via HomeWidget.saveWidgetData (widgetPayloadKey).
  static let payloadKey = "sb_widget_payload"
  /// Written by ToggleAmountsIntent from the Balance widget.
  static let hideAmountsKey = "sb_hide_amounts"
  /// Payload versions this extension understands.
  static let supportedPayloadVersion = 1

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }
}

// MARK: - Payload

struct WidgetPayload: Decodable, Equatable {
  struct Strings: Decodable, Equatable {
    let youAreOwed: String
    let youOwe: String
    let allSettled: String
    let updatedAt: String
    let scan: String
    let settleWith: String
    let noBalances: String
    let signIn: String
    let hide: String
    let show: String
  }

  struct Balance: Decodable, Equatable {
    let label: String
    let amount: String
    let sign: Int
    let value: Double
    let count: Int
  }

  struct Person: Decodable, Equatable, Identifiable {
    let id: String
    let name: String
    let amount: String
    let sign: Int
    let url: String
  }

  let v: Int
  let state: String
  let locale: String
  let dir: String
  let strings: Strings
  let scanUrl: String
  let homeUrl: String
  let balance: Balance?
  let people: [Person]?

  var isSignedIn: Bool { state == "ready" && balance != nil }
  var isRightToLeft: Bool { dir == "rtl" }

  static func decode(_ json: String?) -> WidgetPayload? {
    guard let data = json?.data(using: .utf8),
      let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data),
      payload.v <= SplitBillHomeWidgetFlavor.supportedPayloadVersion
    else { return nil }
    return payload
  }

  static func load() -> WidgetPayload? {
    decode(SplitBillHomeWidgetFlavor.defaults?.string(forKey: SplitBillHomeWidgetFlavor.payloadKey))
  }

  /// Gallery preview before the app has synced: the design's sample data
  /// with native (String Catalog) labels.
  static var sample: WidgetPayload {
    let owed = String(localized: "widget_you_are_owed_sample", defaultValue: "You're owed")
    let settle = String(localized: "widget_settle_name", defaultValue: "Settle with")
    let scan = String(localized: "widget_scan_receipt_sample", defaultValue: "Scan a receipt")
    let open = String(localized: "widget_open_app", defaultValue: "Open Evens to see your balances")
    return WidgetPayload(
      v: 1, state: "ready", locale: Locale.current.identifier,
      dir: Locale.Language(identifier: Locale.current.identifier).characterDirection == .rightToLeft
        ? "rtl" : "ltr",
      strings: Strings(
        youAreOwed: owed, youOwe: owed, allSettled: owed, updatedAt: "",
        scan: scan, settleWith: settle, noBalances: open, signIn: open,
        hide: "", show: ""),
      scanUrl: "splitbill://widget/scan?homeWidget",
      homeUrl: "splitbill://widget/home?homeWidget",
      balance: Balance(label: owed, amount: "+$62.40", sign: 1, value: 62.40, count: 3),
      people: [
        Person(id: "1", name: "Sara", amount: "+54.10", sign: 1, url: "splitbill://widget/home?homeWidget"),
        Person(id: "2", name: "Ali", amount: "+32.30", sign: 1, url: "splitbill://widget/home?homeWidget"),
        Person(id: "3", name: "Mona", amount: "\u{2212}24.00", sign: -1, url: "splitbill://widget/home?homeWidget"),
      ])
  }
}

// MARK: - Timeline

struct SplitBillEntry: TimelineEntry {
  let date: Date
  /// nil until the app has written a payload (first launch).
  let payload: WidgetPayload?
  let amountsHidden: Bool
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SplitBillEntry {
    SplitBillEntry(date: Date(), payload: .sample, amountsHidden: false)
  }

  func getSnapshot(in context: Context, completion: @escaping (SplitBillEntry) -> Void) {
    let payload = WidgetPayload.load()
    completion(
      SplitBillEntry(
        date: Date(),
        payload: payload ?? (context.isPreview ? .sample : nil),
        amountsHidden: SplitBillHomeWidgetFlavor.defaults?.bool(
          forKey: SplitBillHomeWidgetFlavor.hideAmountsKey) ?? false))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SplitBillEntry>) -> Void) {
    // Flutter reloads the timelines whenever balances change, so a single
    // entry is enough; .never avoids wasting the reload budget.
    getSnapshot(in: context) { entry in
      completion(Timeline(entries: [entry], policy: .never))
    }
  }
}

// MARK: - Theme (docs System.dc.html)

enum SplitBillTheme {
  private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
    Color(
      UIColor { traits in
        UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
      })
  }

  static let surface = dynamic(0xFFFFFF, 0x171918)
  static let ink = dynamic(0x111312, 0xF2F3F1)
  static let muted = dynamic(0x5F6360, 0xA3A8A5)
  static let teal = dynamic(0x0F766E, 0x34C5B0)
  static let amber = dynamic(0xB45309, 0xF0B35E)
  /// Text on the teal Quick scan tile.
  static let onTeal = dynamic(0xFFFFFF, 0x0E0F0E)

  static func amountColor(sign: Int) -> Color {
    sign > 0 ? teal : sign < 0 ? amber : ink
  }
}

extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1)
  }
}

// MARK: - App Intent (iOS 17 interactive widget)

/// Hides or shows amounts on the Balance widget without opening the app
/// (privacy on a shared home screen). Runs inside the widget extension; the
/// system reloads the timeline after perform().
struct ToggleAmountsIntent: AppIntent {
  static var title: LocalizedStringResource = "widget_toggle_amounts_intent"
  static var isDiscoverable: Bool = false

  func perform() async throws -> some IntentResult {
    let defaults = SplitBillHomeWidgetFlavor.defaults
    let key = SplitBillHomeWidgetFlavor.hideAmountsKey
    defaults?.set(!(defaults?.bool(forKey: key) ?? false), forKey: key)
    return .result()
  }
}

// MARK: - Shared view helpers

extension View {
  /// Applies the payload's language and direction (the app's in-app
  /// language may differ from the device language).
  func payloadEnvironment(_ payload: WidgetPayload?) -> some View {
    let rtl =
      payload?.isRightToLeft
      ?? (Locale.Language(identifier: Locale.current.identifier).characterDirection == .rightToLeft)
    return
      self
      .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
      .environment(\.locale, payload.map { Locale(identifier: $0.locale) } ?? .current)
  }
}

extension URL {
  static let splitBillHome = URL(string: "splitbill://widget/home?homeWidget")!
  static let splitBillScan = URL(string: "splitbill://widget/scan?homeWidget")!
}
