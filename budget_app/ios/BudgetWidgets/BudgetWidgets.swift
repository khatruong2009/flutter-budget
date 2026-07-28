import SwiftUI
import WidgetKit

/// Reads the safe-to-spend value the app writes to the shared app group.
enum SafeToSpendStore {
  static let suiteName = "group.com.khatruong.budgetbuddy"

  /// Returns nil when the app has never written data (fresh install).
  /// Returns 0 when the stored value belongs to a previous month.
  static func read(for date: Date = Date()) -> Double? {
    guard let defaults = UserDefaults(suiteName: suiteName),
      defaults.object(forKey: "safeToSpend") != nil,
      let storedMonth = defaults.string(forKey: "safeToSpendMonth")
    else { return nil }
    guard storedMonth == monthKey(for: date) else { return 0 }
    return defaults.double(forKey: "safeToSpend")
  }

  /// Always Gregorian: the key must match what the Dart side writes from
  /// DateTime.now(), regardless of the device calendar setting.
  private static var gregorian: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone.current
    return calendar
  }

  static func monthKey(for date: Date) -> String {
    let components = gregorian.dateComponents([.year, .month], from: date)
    return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
  }

  static func startOfNextMonth(after date: Date) -> Date {
    gregorian.dateInterval(of: .month, for: date)?.end
      ?? date.addingTimeInterval(24 * 60 * 60)
  }
}

/// Logo + safe-to-spend strip shown at the top of every Budgie widget.
struct BudgieWidgetHeader: View {
  let safeToSpend: Double?

  var body: some View {
    HStack(spacing: 5) {
      Image("BudgieLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)
      if let amount = safeToSpend {
        Spacer(minLength: 4)
        Text(Self.formattedAmount(amount))
          .font(.system(size: 12, weight: .bold, design: .rounded))
          .foregroundColor(
            amount < 0
              ? Color(red: 0.95, green: 0.55, blue: 0.50)
              : Color(red: 0.55, green: 0.85, blue: 0.62)
          )
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      } else {
        Text("Budgie")
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white.opacity(0.75))
        Spacer(minLength: 0)
      }
    }
  }

  static func formattedAmount(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.locale = Locale(identifier: "en_US")
    formatter.maximumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "$0"
  }
}

struct BudgetQuickActionsEntry: TimelineEntry {
  let date: Date
  let safeToSpend: Double?
}

struct BudgetQuickActionsProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetQuickActionsEntry {
    BudgetQuickActionsEntry(date: Date(), safeToSpend: SafeToSpendStore.read())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetQuickActionsEntry) -> Void) {
    completion(BudgetQuickActionsEntry(date: Date(), safeToSpend: SafeToSpendStore.read()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetQuickActionsEntry>) -> Void) {
    let now = Date()
    let entry = BudgetQuickActionsEntry(date: now, safeToSpend: SafeToSpendStore.read(for: now))
    completion(Timeline(entries: [entry], policy: .after(SafeToSpendStore.startOfNextMonth(after: now))))
  }
}

struct BudgetQuickActionsEntryView: View {
  var entry: BudgetQuickActionsProvider.Entry

  private let incomeURL = URL(string: "budgetapp://add-income")!
  private let expenseURL = URL(string: "budgetapp://add-expense")!

  var body: some View {
    VStack(spacing: 8) {
      BudgieWidgetHeader(safeToSpend: entry.safeToSpend)
      actionButton(
        title: "Income",
        icon: "plus.circle.fill",
        color: Color(red: 0.33, green: 0.74, blue: 0.47),
        destination: incomeURL
      )
      actionButton(
        title: "Expense",
        icon: "minus.circle.fill",
        color: Color(red: 0.90, green: 0.40, blue: 0.35),
        destination: expenseURL
      )
    }
    .padding(6)
    .modifier(BackgroundForVersion())
  }

  private func actionButton(title: String, icon: String, color: Color, destination: URL) -> some View {
    Link(destination: destination) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 18))
        Text(title)
          .fontWeight(.semibold)
          .font(.system(size: 13))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 0)
      }
      .padding(.vertical, 9)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(color)
      )
      .foregroundColor(.white)
    }
    .buttonStyle(.plain)
  }
}

struct BudgetQuickActionsWidget: Widget {
  let kind: String = "BudgetQuickActions"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BudgetQuickActionsProvider()) { entry in
      BudgetQuickActionsEntryView(entry: entry)
    }
    .configurationDisplayName("Budget Quick Add")
    .description("Add income or expense from your home screen.")
    .supportedFamilies([.systemSmall])
  }
}

struct BudgetVoiceAddEntry: TimelineEntry {
  let date: Date
  let safeToSpend: Double?
}

struct BudgetVoiceAddProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetVoiceAddEntry {
    BudgetVoiceAddEntry(date: Date(), safeToSpend: SafeToSpendStore.read())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetVoiceAddEntry) -> Void) {
    completion(BudgetVoiceAddEntry(date: Date(), safeToSpend: SafeToSpendStore.read()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetVoiceAddEntry>) -> Void) {
    let now = Date()
    let entry = BudgetVoiceAddEntry(date: now, safeToSpend: SafeToSpendStore.read(for: now))
    completion(Timeline(entries: [entry], policy: .after(SafeToSpendStore.startOfNextMonth(after: now))))
  }
}

struct BudgetVoiceAddEntryView: View {
  var entry: BudgetVoiceAddProvider.Entry

  private let accentColor = Color(red: 0.51, green: 0.55, blue: 0.97)

  var body: some View {
    VStack(spacing: 0) {
      BudgieWidgetHeader(safeToSpend: entry.safeToSpend)
      Spacer(minLength: 0)
      Image(systemName: "mic.fill")
        .font(.system(size: 26))
        .foregroundColor(.white)
        .frame(width: 52, height: 52)
        .background(
          Circle()
            .fill(accentColor)
        )
      Spacer(minLength: 0)
    }
    .padding(6)
    .modifier(BackgroundForVersion())
  }
}

struct BudgetVoiceAddWidget: Widget {
  let kind: String = "BudgetVoiceAdd"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BudgetVoiceAddProvider()) { entry in
      BudgetVoiceAddEntryView(entry: entry)
        .widgetURL(URL(string: "budgetapp://voice-add")!)
    }
    .configurationDisplayName("Voice Add")
    .description("Speak a transaction and review it before saving.")
    .supportedFamilies([.systemSmall])
  }
}

struct BackgroundForVersion: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOS 17.0, *) {
      content.containerBackground(for: .widget) {
        LinearGradient(
          colors: [
            Color(red: 0.10, green: 0.12, blue: 0.25),
            Color(red: 0.07, green: 0.09, blue: 0.20)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
    } else {
      content.background(
        LinearGradient(
          colors: [
            Color(red: 0.10, green: 0.12, blue: 0.25),
            Color(red: 0.07, green: 0.09, blue: 0.20)
          ],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
    }
  }
}
