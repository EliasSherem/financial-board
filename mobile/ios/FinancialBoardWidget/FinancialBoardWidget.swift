import WidgetKit
import SwiftUI

private let appGroupId = "group.mx.com.finsight"
private let widgetDeepLink = URL(string: "financialboard://widget/create-transaction")!
private let widgetRecurringDeepLink = URL(string: "financialboard://widget/create-recurring-payment")!

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
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
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

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.14, green: 0.37, blue: 0.87),
                    Color(red: 0.10, green: 0.28, blue: 0.73)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(18)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spent this month")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color.white.opacity(0.7))
                        .textCase(.uppercase)
                    Text(entry.amountText)
                        .font(family == .systemSmall ? .title3 : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text(entry.monthLabel)
                        .font(.caption)
                        .foregroundColor(Color.white.opacity(0.72))
                }

                Spacer(minLength: 8)

                VStack(spacing: 8) {
                    Link(destination: widgetDeepLink) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color.white)
                            Text("New transaction")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(14)
                    }

                    Link(destination: widgetRecurringDeepLink) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundColor(Color.white)
                            Text("New recurring payment")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(14)
                    }
                }
            }
            .padding()
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
        .description("Keep an eye on this month's spend and create a transaction or recurring payment instantly.")
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
