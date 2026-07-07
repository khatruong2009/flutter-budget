import SwiftUI
import WidgetKit

struct BudgetQuickActionsEntry: TimelineEntry {
  let date: Date
}

struct BudgetQuickActionsProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetQuickActionsEntry {
    BudgetQuickActionsEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetQuickActionsEntry) -> Void) {
    completion(BudgetQuickActionsEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetQuickActionsEntry>) -> Void) {
    let entry = BudgetQuickActionsEntry(date: Date())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct BudgetQuickActionsEntryView: View {
  var entry: BudgetQuickActionsProvider.Entry

  private let incomeURL = URL(string: "budgetapp://add-income")!
  private let expenseURL = URL(string: "budgetapp://add-expense")!

  var body: some View {
    VStack(spacing: 10) {
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
    .padding(8)
    .modifier(BackgroundForVersion())
  }

  private func actionButton(title: String, icon: String, color: Color, destination: URL) -> some View {
    Link(destination: destination) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.system(size: 20))
        Text(title)
          .fontWeight(.semibold)
          .font(.system(size: 14))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer(minLength: 0)
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 10)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
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
}

struct BudgetVoiceAddProvider: TimelineProvider {
  func placeholder(in context: Context) -> BudgetVoiceAddEntry {
    BudgetVoiceAddEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (BudgetVoiceAddEntry) -> Void) {
    completion(BudgetVoiceAddEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetVoiceAddEntry>) -> Void) {
    let entry = BudgetVoiceAddEntry(date: Date())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct BudgetVoiceAddEntryView: View {
  var entry: BudgetVoiceAddProvider.Entry

  private let accentColor = Color(red: 0.51, green: 0.55, blue: 0.97)

  var body: some View {
    VStack {
      Image(systemName: "mic.fill")
        .font(.system(size: 28))
        .foregroundColor(.white)
        .frame(width: 56, height: 56)
        .background(
          Circle()
            .fill(accentColor)
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    .description("Speak an expense and Budgie logs it.")
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
