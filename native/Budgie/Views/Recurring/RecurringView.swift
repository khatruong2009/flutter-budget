import BudgieCore
import SwiftUI

/// The Recurring page (`RecurringTransactionsPage`,
/// recurring_transactions_page.dart), pushed from Settings > DATA, on the
/// redesign tokens (D1, D15): one `RecurringCard` per template, active ones
/// first, then paused ones, each in stored order; Flutter's empty state; the
/// bar's refresh runs "Generate Due Transactions" and "+" opens the form.
///
/// Differences from Flutter (PARITY_GAPS): the "+" add button, pause /
/// resume and the Paused state (approved MVP behaviours); the empty state
/// also offers "Add Recurring"; the generate and delete writes are awaited
/// and a failed write shows the save-failed toast instead of Flutter's.
struct RecurringView: View {
    @Environment(AppModel.self) private var model

    @State private var sheet: FormSheet?
    @State private var pendingDelete: RecurringTemplate?
    @State private var generating = false
    @State private var generateTaps = 0
    @State private var deleteConfirms = 0

    enum FormSheet: Identifiable {
        case add
        case edit(RecurringTemplate)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let template): "edit-" + template.id
            }
        }

        var template: RecurringTemplate? {
            if case .edit(let template) = self { template } else { nil }
        }
    }

    var body: some View {
        Group {
            if let data = model.data {
                let templates = data.templates.filter(\.isActive) + data.templates.filter { !$0.isActive }
                if templates.isEmpty {
                    emptyState
                } else {
                    list(templates)
                }
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BudgieColor.background)
        .navigationTitle("Recurring Transactions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Recurring Transactions")
                    .textStyle(.cardTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task { await generateDue() }
                } label: {
                    Image(systemName: "arrow.clockwise").foregroundStyle(BudgieColor.textPrimary)
                }
                .disabled(generating || model.data == nil)
                .accessibilityLabel("Generate Due Transactions")
                .accessibilityIdentifier("recurring.generate")
                Button {
                    sheet = .add
                } label: {
                    Image(systemName: "plus").foregroundStyle(BudgieColor.textPrimary)
                }
                .disabled(model.data == nil)
                .accessibilityLabel("Add recurring transaction")
                .accessibilityIdentifier("recurring.add")
            }
        }
        .sheet(item: $sheet) { sheet in
            RecurringFormView(template: sheet.template)
        }
        .alert("Delete Recurring Transaction?", isPresented: deleteAlertBinding, presenting: pendingDelete) { template in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteConfirms += 1
                Task { await delete(template) }
            }
        } message: { template in
            Text(Self.deleteMessage(template.description))
        }
        .sensoryFeedback(.impact(weight: .light), trigger: generateTaps)
        .sensoryFeedback(.impact(weight: .heavy), trigger: deleteConfirms)
    }

    /// `_deleteRecurring`'s content (recurring_transactions_page.dart:170-176).
    static func deleteMessage(_ description: String) -> String {
        "This will stop generating future transactions for \"\(description)\". "
            + "Previously generated transactions will not be affected."
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: - Content

    private func list(_ templates: [RecurringTemplate]) -> some View {
        ScrollView {
            LazyVStack(spacing: Metrics.spacingS) {
                ForEach(templates) { template in
                    RecurringCard(
                        template: template,
                        onEdit: { sheet = .edit(template) },
                        onToggleActive: { Task { await setActive(template, !template.isActive) } },
                        onDelete: { pendingDelete = template })
                }
            }
            .padding(Metrics.spacingM)
        }
        .accessibilityIdentifier("recurring.list")
    }

    /// `_buildEmptyState` (:68-108): a 120pt primary-gradient circle with a
    /// repeat glyph, the title and the two-line message, centred. SF
    /// `repeat` at 52pt is as tall as Material's 60pt `repeat` (about 49pt;
    /// SF's is wider, with rounded corners).
    private var emptyState: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Image(systemName: "repeat")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 120, height: 120)
                        .background(BudgieColor.primaryGradient, in: Circle())
                        .accessibilityHidden(true)
                    Text("No Recurring Transactions")
                        .textStyle(.headingLarge)
                        .foregroundStyle(BudgieColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, Metrics.spacingL)
                    Text("Create recurring transactions to automatically\ngenerate expenses and income on a schedule")
                        .textStyle(.bodyMedium)
                        .foregroundStyle(BudgieColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, Metrics.spacingS)
                    PillButton(title: "Add Recurring", symbol: "plus", filled: true) { sheet = .add }
                        .frame(maxWidth: 260)
                        .padding(.top, Metrics.spacingXL)
                        .accessibilityIdentifier("recurring.empty.add")
                }
                .padding(Metrics.spacingXL)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .accessibilityIdentifier("recurring.empty")
    }

    // MARK: - Actions

    /// `_generateDueTransactions` (:120-146): Flutter's message whether or
    /// not anything was due; the save-failed toast when the write failed.
    private func generateDue() async {
        guard !generating else { return }
        generateTaps += 1
        generating = true
        let result = await model.generateDueNow()
        generating = false
        model.showToast(result.toast)
    }

    private func setActive(_ template: RecurringTemplate, _ active: Bool) async {
        guard hasTemplate(template.id) else { return }
        if !(await model.setTemplateActive(id: template.id, active)) { model.showToast(.saveFailed) }
    }

    private func delete(_ template: RecurringTemplate) async {
        // Already gone (deleted elsewhere): nothing failed.
        guard hasTemplate(template.id) else { return }
        let saved = await model.deleteTemplate(id: template.id)
        model.showToast(saved ? .recurringDeleted : .saveFailed)
    }

    private func hasTemplate(_ id: String) -> Bool {
        model.data?.templates.contains { $0.id == id } ?? false
    }
}
