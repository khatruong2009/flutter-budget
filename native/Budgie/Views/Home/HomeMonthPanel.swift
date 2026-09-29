import BudgieCore
import SwiftUI

/// The month picker under Home's pill (spending_page.dart:1001-1054): a
/// card with a 128pt wheel of the twelve month names, clipped to its
/// height like Flutter's `AnimatedSize` (the caller toggles `expanded` in a
/// 250ms easeInOut transaction, none under Reduce Motion). The wheel always shows `model.selectedMonth`
/// (Flutter's wheel keeps its first month), and a year stepper above it
/// changes the year while keeping the month (D13; Flutter's Home cannot
/// change the year).
struct HomeMonthPanel: View {
    let expanded: Bool

    @Environment(AppModel.self) private var model
    @State private var naturalHeight: CGFloat = 0

    var body: some View {
        panel
            .fixedSize(horizontal: false, vertical: true)
            .onGeometryChangeCompat { naturalHeight = $0.height }
            .frame(height: expanded ? naturalHeight : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(expanded)
            .accessibilityHidden(!expanded)
    }

    private var panel: some View {
        GlowCard(padding: 0) {
            VStack(spacing: 0) {
                YearStepper()
                MonthWheel()
            }
            .padding(.vertical, 8)
        }
        .padding(EdgeInsets(top: 12, leading: Metrics.pageHorizontal, bottom: 0, trailing: Metrics.pageHorizontal))
    }
}

/// Previous year, the year, next year. Stepping keeps the month.
private struct YearStepper: View {
    @Environment(AppModel.self) private var model
    @State private var taps = 0

    var body: some View {
        let month = model.selectedMonth
        HStack(spacing: 0) {
            button("chevron.left", label: "Previous year") { step(month, by: -1) }
            Text(DartDateFormat.y(month))
                .textStyle(.rowTitle)
                .foregroundStyle(BudgieColor.textPrimary)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Year \(DartDateFormat.y(month))")
            button("chevron.right", label: "Next year") { step(month, by: 1) }
        }
        .padding(.horizontal, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }

    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BudgieColor.textSecondary)
                .frame(width: Metrics.touchTarget, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ month: DartDateTime, by years: Int) {
        taps += 1
        let f = month.fields
        model.selectMonth(model.calendar.date(f.year + years, f.month))
    }
}

/// The month wheel (`CupertinoPicker`, itemExtent 34, rows in rowTitle at
/// 16): the native wheel, with its dimmed off-centre rows, rounded
/// selection band and a selection tick per row.
private struct MonthWheel: View {
    @Environment(AppModel.self) private var model

    /// Fixed English names, as Flutter's `_months` (spending_page.dart:34-47).
    private static let names = [
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November",
        "December",
    ]
    private static let row = TextSpec(face: .gabaritoSemiBold, size: 16, height: 1.25, relativeTo: .body)

    var body: some View {
        let selection = Binding(
            get: { model.selectedMonth.month - 1 },
            set: { index in model.selectMonth(model.calendar.date(model.selectedMonth.year, index + 1)) })
        Picker("Month", selection: selection) {
            ForEach(Self.names.indices, id: \.self) { index in
                Text(Self.names[index])
                    .textStyle(Self.row)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .tag(index)
            }
        }
        .pickerStyle(.wheel)
        .frame(height: 128)
        .clipped()
    }
}
