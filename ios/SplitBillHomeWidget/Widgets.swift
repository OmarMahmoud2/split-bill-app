// The four Evens widgets. Kinds must match HomeWidgetService.iOSKinds.
//
// Animation: WidgetKit has no imperative withAnimation in an extension;
// changes between timeline entries animate through the content transitions
// and implicit .animation(_:value:) modifiers below (iOS 17+), e.g. the
// balance counts up/down with .numericText when Flutter pushes a new value.

import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Balance (systemSmall)

struct BalanceWidgetView: View {
  let entry: SplitBillEntry

  var body: some View {
    Group {
      if let payload = entry.payload, let balance = payload.balance, payload.isSignedIn {
        content(payload, balance)
      } else {
        MessageView(
          icon: "person.crop.circle.badge.questionmark",
          text: entry.payload?.strings.signIn
            ?? String(localized: "widget_open_app", defaultValue: "Open Evens to see your balances"))
      }
    }
    .widgetURL(.splitBillHome)
    .containerBackground(for: .widget) { SplitBillTheme.surface }
    .payloadEnvironment(entry.payload)
  }

  private func content(_ payload: WidgetPayload, _ balance: WidgetPayload.Balance) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline) {
        Text(balance.label)
          .font(.caption.weight(.semibold))
          .foregroundStyle(SplitBillTheme.muted)
          .lineLimit(1)
        Spacer(minLength: 4)
        Button(intent: ToggleAmountsIntent()) {
          Image(systemName: entry.amountsHidden ? "eye.slash" : "eye")
            .font(.caption.weight(.semibold))
            .foregroundStyle(SplitBillTheme.muted)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.amountsHidden ? payload.strings.show : payload.strings.hide)
      }
      Spacer(minLength: 6)
      Text(entry.amountsHidden ? "••••" : balance.amount)
        .font(.system(size: 30, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(SplitBillTheme.amountColor(sign: balance.sign))
        .lineLimit(1)
        .minimumScaleFactor(0.45)
        .contentTransition(.numericText(value: entry.amountsHidden ? 0 : balance.value))
        .invalidatableContent()
      Spacer(minLength: 6)
      HStack(spacing: 4) {
        if balance.count > 0 {
          Image(systemName: "person.2.fill")
          Text(balance.count, format: .number)
            .contentTransition(.numericText(value: Double(balance.count)))
          Text(verbatim: "·")
        }
        Text(payload.strings.updatedAt)
      }
      .font(.caption2)
      .foregroundStyle(SplitBillTheme.muted)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .animation(.smooth(duration: 0.45), value: balance)
    .animation(.smooth, value: entry.amountsHidden)
  }
}

struct BalanceWidget: Widget {
  let kind = "SplitBillBalanceWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      BalanceWidgetView(entry: entry)
    }
    .configurationDisplayName(LocalizedStringResource("widget_balance_name"))
    .description(LocalizedStringResource("widget_balance_description"))
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - Quick scan (systemSmall)

struct ScanWidgetView: View {
  let entry: SplitBillEntry

  var body: some View {
    VStack(alignment: .leading) {
      Image(systemName: "viewfinder")
        .font(.system(size: 28, weight: .medium))
        .accessibilityHidden(true)
      Spacer()
      Text(
        entry.payload?.strings.scan
          ?? String(localized: "widget_scan_receipt_sample", defaultValue: "Scan a receipt")
      )
      .font(.system(size: 16, weight: .semibold))
      .lineLimit(2)
      .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .foregroundStyle(SplitBillTheme.onTeal)
    .widgetURL(entry.payload.flatMap { URL(string: $0.scanUrl) } ?? .splitBillScan)
    .containerBackground(for: .widget) { SplitBillTheme.teal }
    .payloadEnvironment(entry.payload)
  }
}

struct ScanWidget: Widget {
  let kind = "SplitBillScanWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      ScanWidgetView(entry: entry)
    }
    .configurationDisplayName(LocalizedStringResource("widget_scan_name"))
    .description(LocalizedStringResource("widget_scan_description"))
    .supportedFamilies([.systemSmall])
  }
}

// MARK: - Settle with (systemMedium)

struct SettleWidgetView: View {
  let entry: SplitBillEntry

  var body: some View {
    Group {
      if let payload = entry.payload, payload.isSignedIn {
        content(payload)
      } else {
        MessageView(
          icon: "person.2",
          text: entry.payload?.strings.signIn
            ?? String(localized: "widget_open_app", defaultValue: "Open Evens to see your balances"))
      }
    }
    .widgetURL(.splitBillHome)
    .containerBackground(for: .widget) { SplitBillTheme.surface }
    .payloadEnvironment(entry.payload)
  }

  private func content(_ payload: WidgetPayload) -> some View {
    let people = payload.people ?? []
    return VStack(alignment: .leading, spacing: 10) {
      Text(payload.strings.settleWith)
        .font(.caption.weight(.semibold))
        .foregroundStyle(SplitBillTheme.muted)
      if people.isEmpty {
        Spacer(minLength: 0)
        Text(payload.strings.noBalances)
          .font(.subheadline)
          .foregroundStyle(SplitBillTheme.muted)
          .frame(maxWidth: .infinity)
        Spacer(minLength: 0)
      } else {
        ForEach(people) { person in
          Link(destination: URL(string: person.url) ?? .splitBillHome) {
            HStack {
              Text(person.name)
                .font(.subheadline)
                .foregroundStyle(SplitBillTheme.ink)
                .lineLimit(1)
              Spacer(minLength: 8)
              Text(entry.amountsHidden ? "••••" : person.amount)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(SplitBillTheme.amountColor(sign: person.sign))
                .contentTransition(.numericText())
            }
          }
          .transition(.push(from: .bottom))
        }
        Spacer(minLength: 0)
      }
    }
    .animation(.smooth(duration: 0.45), value: people)
  }
}

struct SettleWidget: Widget {
  let kind = "SplitBillSettleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      SettleWidgetView(entry: entry)
    }
    .configurationDisplayName(LocalizedStringResource("widget_settle_name"))
    .description(LocalizedStringResource("widget_settle_description"))
    .supportedFamilies([.systemMedium])
  }
}

// MARK: - Lock Screen (accessoryRectangular / accessoryInline)

struct BalanceAccessoryView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SplitBillEntry

  var body: some View {
    Group {
      if let payload = entry.payload, let balance = payload.balance, payload.isSignedIn {
        let amount = entry.amountsHidden ? "••••" : balance.amount
        if family == .accessoryInline {
          Text(verbatim: "\(balance.label) \(amount)")
        } else {
          VStack(alignment: .leading, spacing: 0) {
            Text(balance.label)
              .font(.caption.weight(.semibold))
              .widgetAccentable()
            Text(amount)
              .font(.title3.weight(.bold))
              .monospacedDigit()
              .lineLimit(1)
              .minimumScaleFactor(0.6)
              .contentTransition(.numericText(value: balance.value))
            Text(payload.strings.updatedAt)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .animation(.smooth, value: balance)
        }
      } else {
        Text(
          entry.payload?.strings.signIn
            ?? String(localized: "widget_open_app", defaultValue: "Open Evens to see your balances")
        )
        .font(.caption)
        .lineLimit(2)
      }
    }
    .widgetURL(.splitBillHome)
    .containerBackground(for: .widget) { Color.clear }
    .payloadEnvironment(entry.payload)
  }
}

struct BalanceAccessoryWidget: Widget {
  let kind = "SplitBillBalanceAccessory"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      BalanceAccessoryView(entry: entry)
    }
    .configurationDisplayName(LocalizedStringResource("widget_accessory_name"))
    .description(LocalizedStringResource("widget_accessory_description"))
    .supportedFamilies([.accessoryRectangular, .accessoryInline])
  }
}

// MARK: - Shared

struct MessageView: View {
  let icon: String
  let text: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: icon)
        .font(.title3)
        .foregroundStyle(SplitBillTheme.teal)
        .accessibilityHidden(true)
      Spacer(minLength: 0)
      Text(text)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(SplitBillTheme.ink)
        .lineLimit(3)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

// MARK: - Previews

#Preview("Balance", as: .systemSmall) {
  BalanceWidget()
} timeline: {
  SplitBillEntry(date: .now, payload: .sample, amountsHidden: false)
  SplitBillEntry(date: .now, payload: .sample, amountsHidden: true)
}

#Preview("Settle", as: .systemMedium) {
  SettleWidget()
} timeline: {
  SplitBillEntry(date: .now, payload: .sample, amountsHidden: false)
}
