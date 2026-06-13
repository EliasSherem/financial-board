import SwiftUI
import WidgetKit

private let appGroupId = "group.mx.com.finsight"
private let widgetDeepLink = URL(string: "financialboard://widget/create-transaction")!
private let widgetScanReceiptDeepLink = URL(string: "financialboard://widget/scan-receipt")!

struct SpendEntry: TimelineEntry {
  let date: Date
  let amountText: String
  let monthLabel: String
  let themeMode: String
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SpendEntry {
    SpendEntry(date: Date(), amountText: "$0.00", monthLabel: "This month", themeMode: "system")
  }

  func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
    let entry = loadEntry()
    // Refresh roughly every 30 minutes in case the user leaves the widget visible.
    let next =
      Calendar.current.date(byAdding: .minute, value: 30, to: Date())
      ?? Date().addingTimeInterval(1800)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }

  private func loadEntry() -> SpendEntry {
    let defaults = UserDefaults(suiteName: appGroupId)
    let amount = defaults?.string(forKey: "kpi_spent_display") ?? "$0.00"
    let month = defaults?.string(forKey: "kpi_spent_month_label") ?? "This month"
    let themeMode = defaults?.string(forKey: "widget_theme_mode") ?? "system"
    return SpendEntry(date: Date(), amountText: amount, monthLabel: month, themeMode: themeMode)
  }
}

struct FinancialBoardWidgetEntryView: View {
  var entry: SpendEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme

  private var usesDarkPalette: Bool {
    switch entry.themeMode {
    case "dark":
      return true
    case "light":
      return false
    default:
      return colorScheme == .dark
    }
  }

  private var shellColor: Color {
    return usesDarkPalette
      ? Color(red: 0.04, green: 0.07, blue: 0.13).opacity(0.62)
      : Color(red: 0.97, green: 0.98, blue: 0.99).opacity(0.58)
  }

  private var shellStroke: Color {
    return usesDarkPalette
      ? Color(red: 0.16, green: 0.23, blue: 0.34).opacity(0.62)
      : Color(red: 0.82, green: 0.87, blue: 0.93).opacity(0.64)
  }

  private var surfaceColor: Color {
    return usesDarkPalette
      ? Color(red: 0.07, green: 0.10, blue: 0.16).opacity(0.58)
      : Color.white.opacity(0.50)
  }

  private var actionColor: Color {
    return usesDarkPalette
      ? Color(red: 0.09, green: 0.17, blue: 0.32).opacity(0.62)
      : Color(red: 0.92, green: 0.96, blue: 1.00).opacity(0.56)
  }

  private var actionStroke: Color {
    return usesDarkPalette
      ? Color(red: 0.18, green: 0.37, blue: 0.66).opacity(0.68)
      : Color(red: 0.72, green: 0.82, blue: 1.00).opacity(0.70)
  }

  private var primaryBlue: Color {
    return usesDarkPalette
      ? Color(red: 0.38, green: 0.65, blue: 0.98)
      : Color(red: 0.15, green: 0.39, blue: 0.92)
  }

  private var primaryText: Color {
    return usesDarkPalette
      ? Color(red: 0.97, green: 0.98, blue: 0.99)
      : Color(red: 0.07, green: 0.09, blue: 0.15)
  }

  private var secondaryText: Color {
    return usesDarkPalette
      ? Color(red: 0.72, green: 0.77, blue: 0.83)
      : Color(red: 0.39, green: 0.45, blue: 0.55)
  }

  private var outerPadding: CGFloat {
    return 8
  }

  private var metricPadding: CGFloat {
    return 8
  }

  private var actionButtonHeight: CGFloat {
    return 32
  }

  private var actionIconSize: CGFloat {
    return 17
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(shellColor)
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(shellStroke, lineWidth: 1)

      VStack(alignment: .leading, spacing: 7) {
        VStack(alignment: .leading, spacing: 1) {
          Text("Spent this month")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(secondaryText)
            .textCase(.uppercase)
          Text(entry.amountText)
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
          Text(entry.monthLabel)
            .font(.caption2)
            .foregroundColor(secondaryText)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(metricPadding)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(surfaceColor)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(shellStroke, lineWidth: 1)
        )

        actionButtons
      }
      .padding(outerPadding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    .widgetURL(widgetDeepLink)
  }

  private var actionButtons: some View {
    VStack(spacing: 5) {
      actionLink(destination: widgetDeepLink, icon: "plus", title: "New transaction")
      actionLink(destination: widgetScanReceiptDeepLink, icon: "camera.viewfinder", title: "Scan receipt")
    }
  }

  private func actionLink(destination: URL, icon: String, title: String) -> some View {
    Link(destination: destination) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: actionIconSize, weight: .semibold))
          .foregroundColor(primaryBlue)
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .fontWeight(.semibold)
          .foregroundColor(primaryBlue)
          .lineLimit(1)
          .minimumScaleFactor(0.74)
      }
      .frame(maxWidth: .infinity)
      .frame(height: actionButtonHeight)
      .background(actionColor)
      .clipShape(Capsule())
      .overlay(Capsule().stroke(actionStroke, lineWidth: 1))
    }
    .buttonStyle(.plain)
  }
}

struct FinancialBoardWidget: Widget {
  let kind: String = "FinancialBoardWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      FinancialBoardWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("FinSight Snapshot")
    .description(
      "Keep an eye on this month's spend and create a transaction or scan a receipt instantly."
    )
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FinancialBoardWidget_Previews: PreviewProvider {
  static var previews: some View {
    FinancialBoardWidgetEntryView(
      entry: SpendEntry(
        date: Date(),
        amountText: "$1,245.32",
        monthLabel: "October 2025",
        themeMode: "system"
      )
    )
    .previewContext(WidgetPreviewContext(family: .systemMedium))
  }
}
