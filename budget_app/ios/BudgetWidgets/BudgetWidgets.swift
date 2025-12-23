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
