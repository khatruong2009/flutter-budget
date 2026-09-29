import BudgieCore
import SwiftUI
import UIKit

/// Settings (Flutter's "More" tab, `settings_page.dart:579-911`), pushed
/// from the Home gear (D2): the title sits in the navigation bar beside the
/// back button, then the brand card and the APPEARANCE, PERSONALIZATION,
/// PRIVACY, DATA and ABOUT cards.
///
/// Differences from Flutter (PARITY_GAPS): Categories, Tags & rules, Import
/// from CSV and the backup rows open an "upcoming update" page until their
/// phase lands; turning App lock on asks for Face ID / the passcode first
/// (Flutter locks at once); ABOUT also lists Data diagnostics and Licences.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var destination: Destination?
    @State private var choice: Choice?
    @State private var exportFile: ExportFile?
    @State private var notice: String?

    var body: some View {
        ScrollView {
            if let data = model.data {
                content(data)
            }
        }
        .background(BudgieColor.background)
        // The system title names the screen (VoiceOver, the back button of
        // pushed pages) but is not drawn: the 26pt title sits at the
        // leading edge instead.
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(BudgieColor.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Color.clear.frame(width: 1, height: 1).accessibilityHidden(true)
            }
            SettingsBarTitle {
                // Capped so the largest text sizes cannot push it past the
                // bar or into the back button.
                Text("Settings")
                    .textStyle(.pageTitle)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .fixedSize()
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .navigationDestination(item: $destination) { $0.view }
        .sheet(item: $choice) { choiceSheet($0) }
        .sheet(item: $exportFile) { file in
            ActivityView(url: file.url) { completed in
                if completed { model.showToast(Toast(message: "Transactions exported successfully!")) }
            }
            .ignoresSafeArea()
        }
        .alert("App lock", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    // MARK: - Page

    private func content(_ data: FinancialData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsBrandCard()
                .padding(EdgeInsets(top: Metrics.spacingL, leading: Metrics.pageHorizontal, bottom: 0, trailing: Metrics.pageHorizontal))
            section("Appearance", rows: [AnyView(SettingsThemeRow(selection: themeSelection))])
            section("Personalization", rows: personalizationRows(data))
            section("Privacy", rows: privacyRows(data.appSettings))
            section("Data", rows: dataRows(data))
            section("About", rows: aboutRows)
        }
        .padding(.bottom, Metrics.spacingL)
    }

    private func personalizationRows(_ data: FinancialData) -> [AnyView] {
        let settings = data.appSettings
        let activeCategories = data.categories.filter { !$0.isArchived }.count
        return [
            AnyView(SettingsRow(
                symbol: "square.on.circle", color: BudgieColor.accent, title: "Categories",
                subtitle: "\(activeCategories) active · custom names, icons, and order",
                action: { destination = .categories })),
            AnyView(SettingsRow(
                symbol: "sparkles", color: BudgieColor.info, title: "Tags & rules",
                subtitle: "\(data.tags.count) tags · \(data.rules.count) rules",
                action: { destination = .tagsAndRules })),
            AnyView(SettingsRow(
                symbol: "banknote", color: BudgieColor.income, title: "Currency",
                subtitle: SettingsOptions.currencyLabel(settings.baseCurrencyCode),
                action: { choice = .currency }
            ).accessibilityIdentifier("settings.currency")),
            AnyView(SettingsRow(
                symbol: "globe", color: BudgieColor.info, iconSize: SettingsGlyph.full, title: "Number format",
                subtitle: SettingsOptions.localeLabel(settings.localeOverride),
                action: { choice = .locale }
            ).accessibilityIdentifier("settings.numberFormat")),
        ]
    }

    private func privacyRows(_ settings: AppSettings) -> [AnyView] {
        let delay = SettingsOptions.lockTimeoutLabel(settings.autoLockTimeoutSeconds)
        var rows: [AnyView] = [
            AnyView(SettingsToggleRow(
                symbol: "lock", color: BudgieColor.accent, iconSize: SettingsGlyph.full, title: "App lock",
                subtitle: settings.appLockEnabled ? "Lock after \(delay)" : "Require device authentication",
                isOn: lockBinding, identifier: "settings.appLock"))
        ]
        // Inserted and removed without animation, as in Flutter.
        if settings.appLockEnabled {
            rows.append(AnyView(SettingsRow(
                symbol: "timer", color: BudgieColor.info, iconSize: SettingsGlyph.full, title: "Lock delay", subtitle: delay,
                action: { choice = .lockDelay }
            ).accessibilityIdentifier("settings.lockDelay")))
        }
        rows.append(AnyView(SettingsToggleRow(
            symbol: "eye.slash", color: BudgieColor.warning, title: "Hide balances",
            subtitle: "Mask amounts throughout the app", isOn: hideBinding, identifier: "settings.hideBalances")))
        return rows
    }

    /// Recurring is never disabled; the other four are while an export runs
    /// (Flutter's `_dataBusy`).
    private func dataRows(_ data: FinancialData) -> [AnyView] {
        let busy = exportFile != nil
        // What the export writes (Flutter `transactions.length`), current
        // as soon as a row is added (the ledger index rebuilds later).
        let transactionCount = data.transactions.count
        func unlessBusy(_ action: @escaping () -> Void) -> (() -> Void)? { busy ? nil : action }
        return [
            AnyView(SettingsRow(
                symbol: "repeat", color: BudgieColor.accent, title: "Recurring transactions",
                subtitle: recurringSubtitle(data.templates.filter(\.isActive)),
                action: { destination = .recurring }
            ).accessibilityIdentifier("settings.recurring")),
            AnyView(SettingsRow(
                symbol: "arrow.down.to.line", color: BudgieColor.income, tile: BudgieColor.income.opacity(0.12),
                iconSize: SettingsGlyph.small,
                title: "Export as CSV", subtitle: "All \(transactionCount) transactions", busy: busy,
                action: unlessBusy(export)
            ).accessibilityIdentifier("settings.exportCSV")),
            AnyView(SettingsRow(
                symbol: "arrow.up.to.line", color: BudgieColor.accent, tile: BudgieColor.accent.opacity(0.12),
                iconSize: SettingsGlyph.small,
                title: "Import from CSV", subtitle: "Add transactions from a file",
                action: unlessBusy { destination = .csvImport })),
            AnyView(SettingsRow(
                symbol: "icloud.and.arrow.up", color: BudgieColor.income, tile: BudgieColor.income.opacity(0.12),
                title: "Export backup", subtitle: "Everything, as a JSON file",
                action: unlessBusy { destination = .backupExport })),
            AnyView(SettingsRow(
                symbol: "arrow.counterclockwise.circle", color: BudgieColor.accent, tile: BudgieColor.accent.opacity(0.12),
                title: "Import backup", subtitle: "Restore everything (replaces current data)",
                action: unlessBusy { destination = .backupImport })),
        ]
    }

    /// Version (no action), then the Swift-only pages: what was loaded,
    /// the fonts' licences, and the debug design gallery.
    private var aboutRows: [AnyView] {
        var rows: [AnyView] = [
            AnyView(SettingsRow(
                symbol: "info.circle", color: BudgieColor.versionIcon, tile: BudgieColor.versionTile,
                iconSize: SettingsGlyph.full, title: "Version",
                subtitle: "Budgie \(Self.version)", action: nil, trailing: { EmptyView() })),
            AnyView(SettingsRow(
                symbol: "list.bullet.rectangle", color: BudgieColor.versionIcon, tile: BudgieColor.versionTile,
                title: "Data diagnostics", subtitle: "What this device loaded",
                action: { destination = .diagnostics })),
            AnyView(SettingsRow(
                symbol: "doc.text", color: BudgieColor.versionIcon, tile: BudgieColor.versionTile,
                title: "Licences", subtitle: "Fonts (SIL Open Font License)",
                action: { destination = .licences })),
        ]
        #if DEBUG
        rows.append(AnyView(SettingsRow(
            symbol: "paintpalette", color: BudgieColor.versionIcon, tile: BudgieColor.versionTile,
            title: "Design gallery", subtitle: "Debug builds only",
            action: { destination = .designGallery })))
        #endif
        return rows
    }

    /// An eyebrow and its list card (inset 20, 10 below the eyebrow).
    private func section(_ title: String, rows: [AnyView]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsEyebrow(title: title)
            GlowListCard(rows: rows)
                .padding(EdgeInsets(top: 10, leading: Metrics.pageHorizontal, bottom: 0, trailing: Metrics.pageHorizontal))
        }
    }

    /// `_recurringSubtitle` (sp:913-917): the count and the first three
    /// active descriptions, in list order.
    private func recurringSubtitle(_ active: [RecurringTemplate]) -> String {
        if active.isEmpty { return "No active recurring transactions" }
        return "\(active.count) active · \(active.prefix(3).map(\.description).joined(separator: ", "))"
    }

    /// The marketing version only (Flutter's `PackageInfo.version`, falling
    /// back to 2.0.0).
    private static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0"

    // MARK: - Controls

    /// Light | Dark | Auto, in Flutter's order.
    private static let themeModes: [ThemeMode] = [.light, .dark, .system]

    private var themeSelection: Binding<Int> {
        Binding(
            get: { Self.themeModes.firstIndex(of: model.themeMode) ?? 2 },
            set: { model.setThemeMode(Self.themeModes[$0]) })
    }

    /// Turning the lock on authenticates first and keeps this session
    /// unlocked; turning it off needs nothing. The switch stays on while the
    /// prompt is up and goes back off only if it fails.
    private var lockBinding: Binding<Bool> {
        Binding(
            get: { model.data?.appSettings.appLockEnabled == true || model.isEnablingAppLock },
            set: { enable in
                guard enable else {
                    Task { await model.setAppLockEnabled(false) }
                    return
                }
                guard !model.isEnablingAppLock else { return }
                model.setEnablingAppLock(true)
                Task {
                    switch await DeviceAuth.authenticate(reason: "Turn on App Lock") {
                    case .success:
                        model.markUnlocked()
                        await model.setAppLockEnabled(true)
                    case .failed: break
                    case .unavailable: notice = "Set a passcode in the Settings app to use App Lock."
                    }
                    model.setEnablingAppLock(false)
                }
            })
    }

    private var hideBinding: Binding<Bool> {
        Binding(
            get: { model.data?.appSettings.hideBalances == true },
            set: { hidden in Task { await model.setHideBalances(hidden) } })
    }

    // MARK: - Sheets

    private enum Choice: String, Identifiable {
        case currency, locale, lockDelay
        var id: String { rawValue }
    }

    @ViewBuilder
    private func choiceSheet(_ choice: Choice) -> some View {
        let settings = model.data?.appSettings
        switch choice {
        case .currency:
            SettingsChoiceSheet(
                title: "Base currency", choices: SettingsOptions.currencies, current: settings?.baseCurrencyCode ?? "USD"
            ) { await model.setBaseCurrency($0) }
        case .locale:
            SettingsChoiceSheet(title: "Number format", choices: SettingsOptions.locales, current: settings?.localeOverride) {
                await model.setLocaleOverride($0)
            }
        case .lockDelay:
            SettingsChoiceSheet(
                title: "Lock delay", choices: SettingsOptions.lockDelays, current: settings?.autoLockTimeoutSeconds ?? 60
            ) { await model.setAutoLockTimeoutSeconds($0) }
        }
    }

    /// `_exportTransactions`: the share sheet, with the row's spinner while
    /// it is open and the success message once the file was shared.
    private func export() {
        do {
            exportFile = ExportFile(url: try model.exportCSV())
        } catch {
            model.showToast(Toast(message: "Error exporting transactions: \(error.localizedDescription)", style: .danger))
        }
    }

    // MARK: - Destinations

    private enum Destination: Hashable {
        case categories, tagsAndRules, recurring, csvImport, backupExport, backupImport, diagnostics, licences
        #if DEBUG
        case designGallery
        #endif

        @MainActor @ViewBuilder var view: some View {
            switch self {
            case .categories: UpcomingSettingsPage(title: "Categories", symbol: "square.on.circle")
            case .tagsAndRules: UpcomingSettingsPage(title: "Tags & rules", symbol: "sparkles")
            case .recurring: RecurringView()
            case .csvImport: UpcomingSettingsPage(title: "Import from CSV", symbol: "arrow.up.to.line")
            case .backupExport: UpcomingSettingsPage(title: "Export backup", symbol: "icloud.and.arrow.up")
            case .backupImport: UpcomingSettingsPage(title: "Import backup", symbol: "arrow.counterclockwise.circle")
            case .diagnostics: DiagnosticsView()
            case .licences: LicencesView()
            #if DEBUG
            case .designGallery: DesignGalleryView()
            #endif
            }
        }
    }
}

/// A Settings row whose feature lands in a later phase.
private struct UpcomingSettingsPage: View {
    let title: String
    let symbol: String

    var body: some View {
        EmptyStateView(symbol: symbol, title: title, message: "This arrives in an upcoming update.")
            .frame(maxHeight: .infinity)
            .background(BudgieColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

/// The page title as a leading navigation bar item, without the bar's own
/// glass capsule around it (iOS 26).
private struct SettingsBarTitle<Content: View>: ToolbarContent {
    @ViewBuilder var content: () -> Content

    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading, content: content)
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading, content: content)
        }
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ActivityView: UIViewControllerRepresentable {
    let url: URL
    let onComplete: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
