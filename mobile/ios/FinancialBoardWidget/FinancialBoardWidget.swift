import SwiftUI
import WidgetKit

private let appGroupId = "group.mx.com.finsight"
private let widgetDeepLink = URL(string: "financialboard://widget/create-transaction")!
private let widgetRecurringDeepLink = URL(
  string: "financialboard://widget/create-recurring-payment")!

struct SpendEntry: TimelineEntry {
  let date: Date
  let amountText: String
  let monthLabel: String
}

struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> SpendEntry {
    SpendEntry(date: Date(), amountText: "$0.00", monthLabel: "This month")
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
    return SpendEntry(date: Date(), amountText: amount, monthLabel: month)
  }
}

struct FinancialBoardWidgetEntryView: View {
  var entry: SpendEntry
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool {
    colorScheme == .dark
  }

  private var shellColor: Color {
    return isDark
      ? Color(red: 0.04, green: 0.07, blue: 0.13)
      : Color(red: 0.97, green: 0.98, blue: 0.99)
  }

  private var shellStroke: Color {
    return isDark
      ? Color(red: 0.16, green: 0.23, blue: 0.34)
      : Color(red: 0.82, green: 0.87, blue: 0.93)
  }

  private var surfaceColor: Color {
    return isDark
      ? Color(red: 0.07, green: 0.10, blue: 0.16)
      : Color.white.opacity(0.92)
  }

  private var actionColor: Color {
    return isDark
      ? Color(red: 0.09, green: 0.17, blue: 0.32)
      : Color(red: 0.92, green: 0.96, blue: 1.00)
  }

  private var actionStroke: Color {
    return isDark
      ? Color(red: 0.18, green: 0.37, blue: 0.66)
      : Color(red: 0.72, green: 0.82, blue: 1.00)
  }

  private var primaryBlue: Color {
    return isDark
      ? Color(red: 0.38, green: 0.65, blue: 0.98)
      : Color(red: 0.15, green: 0.39, blue: 0.92)
  }

  private var primaryText: Color {
    return isDark
      ? Color(red: 0.97, green: 0.98, blue: 0.99)
      : Color(red: 0.07, green: 0.09, blue: 0.15)
  }

  private var secondaryText: Color {
    return isDark
      ? Color(red: 0.72, green: 0.77, blue: 0.83)
      : Color(red: 0.39, green: 0.45, blue: 0.55)
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(shellColor)
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(shellStroke, lineWidth: 1)

      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 5) {
          Text("Spent this month")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(secondaryText)
            .textCase(.uppercase)
          Text(entry.amountText)
            .font(family == .systemSmall ? .title3 : .title2)
            .fontWeight(.bold)
            .foregroundColor(primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
          Text(entry.monthLabel)
            .font(.caption)
            .foregroundColor(secondaryText)
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(surfaceColor)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(shellStroke, lineWidth: 1)
        )

        Spacer(minLength: 4)

        VStack(spacing: 8) {
          Link(destination: widgetDeepLink) {
            HStack(spacing: 8) {
              Image(systemName: "plus.circle")
                .foregroundColor(primaryBlue)
              Text("New transaction")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(actionColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(actionStroke, lineWidth: 1))
          }

          Link(destination: widgetRecurringDeepLink) {
            HStack(spacing: 8) {
              Image(systemName: "arrow.triangle.2.circlepath.circle")
                .foregroundColor(primaryBlue)
              Text("New recurring payment")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(actionColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(actionStroke, lineWidth: 1))
          }
        }
      }
      .padding(12)
    }
    .widgetURL(widgetDeepLink)
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
      "Keep an eye on this month's spend and create a transaction or recurring payment instantly."
    )
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FinancialBoardWidget_Previews: PreviewProvider {
  static var previews: some View {
    FinancialBoardWidgetEntryView(
      entry: SpendEntry(date: Date(), amountText: "$1,245.32", monthLabel: "October 2025")
    )
    .previewContext(WidgetPreviewContext(family: .systemMedium))
  }
}
