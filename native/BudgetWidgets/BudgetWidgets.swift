import SwiftUI
import WidgetKit

/// Reads the cash flow value the app writes to the shared app group.
enum CashFlowStore {
  static let suiteName = "group.com.khatruong.budgetbuddy"

  /// Returns nil when the app has never written data (fresh install).
  /// Returns 0 when the stored value belongs to a previous month.
  static func read(for date: Date = Date()) -> Double? {
    guard let defaults = UserDefaults(suiteName: suiteName),
      defaults.object(forKey: "cashFlow") != nil,
      let storedMonth = defaults.string(forKey: "cashFlowMonth")
    else { return nil }
    guard storedMonth == monthKey(for: date) else { return 0 }
    return defaults.double(forKey: "cashFlow")
  }

  /// The app's Hide balances setting (D12), written by the Swift app only;
  /// false when absent.
  static func hidesBalances() -> Bool {
    UserDefaults(suiteName: suiteName)?.bool(forKey: "budgieHideBalances") ?? false
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

/// The widget target cannot use `BudgieColor` (it lives in the app target), so
/// this repeats the values the widgets need from
/// native/Budgie/DesignSystem/Tokens/Colors.swift, resolved by the widget's
/// colour scheme: "Paper" in light mode, "Midnight" in dark mode.
struct WidgetPalette {
  let colorScheme: ColorScheme

  private func pick(light: UInt32, dark: UInt32) -> Color {
    Color(hex: colorScheme == .dark ? dark : light)
  }

  /// `BudgieColor.card`.
  var background: Color { pick(light: 0xFBF9F4, dark: 0x11151C) }
  var textPrimary: Color { pick(light: 0x1A1A17, dark: 0xEEF1F5) }
  var textSecondary: Color { pick(light: 0x5C584F, dark: 0x9AA3B2) }
  var accent: Color { pick(light: 0x1D6646, dark: 0xB3ADFF) }
  var onAccent: Color { pick(light: 0xFFFFFF, dark: 0x0B0B14) }
  var income: Color { pick(light: 0x1D6646, dark: 0x5EE6B0) }
  var danger: Color { pick(light: 0xA63D24, dark: 0xFF8B7B) }
  /// Fills behind a white label (4.5:1 or better on both).
  var incomeFixed: Color { pick(light: 0x1D6646, dark: 0x0E6B4C) }
  var expenseFixed: Color { pick(light: 0xA63D24, dark: 0xA3372A) }
}

private extension Color {
  /// `hex` is 0xRRGGBB.
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}

/// Logo + cash flow strip shown at the top of the Quick Add widget.
struct BudgieWidgetHeader: View {
  let cashFlow: Double?
  var hidesBalances = false

  @Environment(\.colorScheme) private var colorScheme

  /// MoneyFormatter's masked amount.
  static let hiddenAmount = "\u{2022}\u{2022}\u{2022}\u{2022}"

  private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

  var body: some View {
    HStack(spacing: 6) {
      Image("BudgieLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
      Spacer(minLength: 4)
      if cashFlow != nil, hidesBalances {
        // Neutral colour: income/danger would still tell the sign.
        Text(Self.hiddenAmount)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(palette.textSecondary)
          .lineLimit(1)
          .accessibilityLabel("Balance hidden")
      } else if let amount = cashFlow {
        Text(Self.formattedAmount(amount))
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(amount < 0 ? palette.danger : palette.income)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      } else {
        Text("Budgie")
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundColor(palette.textSecondary)
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
  let cashFlow: Double?
  let hidesBalances: Bool
}

struct BudgetQuickActionsProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetQuickActionsEntry {
    BudgetQuickActionsEntry(date: Date(), cashFlow: CashFlowStore.read(), hidesBalances: CashFlowStore.hidesBalances())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetQuickActionsEntry) -> Void) {
    completion(BudgetQuickActionsEntry(date: Date(), cashFlow: CashFlowStore.read(), hidesBalances: CashFlowStore.hidesBalances()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetQuickActionsEntry>) -> Void) {
    let now = Date()
    let entry = BudgetQuickActionsEntry(date: now, cashFlow: CashFlowStore.read(for: now), hidesBalances: CashFlowStore.hidesBalances())
    completion(Timeline(entries: [entry], policy: .after(CashFlowStore.startOfNextMonth(after: now))))
  }
}

struct BudgetQuickActionsEntryView: View {
  var entry: BudgetQuickActionsProvider.Entry

  @Environment(\.colorScheme) private var colorScheme

  private let incomeURL = URL(string: "budgetapp://add-income")!
  private let expenseURL = URL(string: "budgetapp://add-expense")!

  private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

  var body: some View {
    VStack(spacing: 8) {
      BudgieWidgetHeader(cashFlow: entry.cashFlow, hidesBalances: entry.hidesBalances)
      actionButton(
        title: "Income", symbol: "plus", color: palette.incomeFixed, destination: incomeURL)
      actionButton(
        title: "Expense", symbol: "chevron.down", color: palette.expenseFixed,
        destination: expenseURL)
    }
    .widgetBackground(palette.background)
  }

  private func actionButton(title: String, symbol: String, color: Color, destination: URL)
    -> some View
  {
    Link(destination: destination) {
      HStack(spacing: 6) {
        Image(systemName: symbol)
          .font(.system(size: 13, weight: .heavy))
        Text(title)
          .font(.system(size: 14, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
  let cashFlow: Double?
  let hidesBalances: Bool
}

struct BudgetVoiceAddProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetVoiceAddEntry {
    BudgetVoiceAddEntry(date: Date(), cashFlow: CashFlowStore.read(), hidesBalances: CashFlowStore.hidesBalances())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetVoiceAddEntry) -> Void) {
    completion(BudgetVoiceAddEntry(date: Date(), cashFlow: CashFlowStore.read(), hidesBalances: CashFlowStore.hidesBalances()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetVoiceAddEntry>) -> Void) {
    let now = Date()
    let entry = BudgetVoiceAddEntry(date: now, cashFlow: CashFlowStore.read(for: now), hidesBalances: CashFlowStore.hidesBalances())
    completion(Timeline(entries: [entry], policy: .after(CashFlowStore.startOfNextMonth(after: now))))
  }
}

struct BudgetVoiceAddEntryView: View {
  var entry: BudgetVoiceAddProvider.Entry

  @Environment(\.colorScheme) private var colorScheme

  private var palette: WidgetPalette { WidgetPalette(colorScheme: colorScheme) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Image(systemName: "mic.fill")
        .font(.system(size: 24))
        .foregroundColor(palette.onAccent)
        .frame(width: 52, height: 52)
        .background(Circle().fill(palette.accent))
        .accessibilityHidden(true)
      Spacer(minLength: 0)
      Text("Speak a transaction")
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(palette.textPrimary)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
      Text("Budgie")
        .font(.system(size: 12))
        .foregroundColor(palette.textSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetBackground(palette.background)
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

extension View {
  /// The widget's flat Paper / Midnight background.
  func widgetBackground(_ color: Color) -> some View {
    containerBackground(for: .widget) { color }
  }
}
