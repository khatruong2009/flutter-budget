import BudgieCore
import SwiftUI
import UIKit

/// UI_SPEC "Settings".
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private static let currencies = ["USD", "CAD", "EUR", "GBP", "AUD", "JPY", "CNY", "INR", "KRW", "MXN", "BRL"]

    @State private var biometry = DeviceAuth.biometryName
    @State private var exportFile: ExportFile?
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: Binding(get: { model.themeMode }, set: { model.setThemeMode($0) })) {
                        Text("System").tag(ThemeMode.system)
                        Text("Light").tag(ThemeMode.light)
                        Text("Dark").tag(ThemeMode.dark)
                    }
                }

                Section("Currency") {
                    Picker("Currency", selection: currencyBinding) {
                        ForEach(currencyOptions, id: \.self) { code in
                            Text(currencyLabel(code)).tag(code)
                        }
                    }
                }

                Section {
                    Toggle("\(biometry) Lock", isOn: lockBinding)
                } header: {
                    Text("Security")
                } footer: {
                    Text("Require \(biometry == "Passcode" ? "your passcode" : biometry) to open Budgie.")
                }

                Section("Data") {
                    Button {
                        export()
                    } label: {
                        Label("Export transactions", systemImage: "square.and.arrow.up")
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: versionText)
                    NavigationLink("Data diagnostics") { DiagnosticsView() }
                    NavigationLink("Licences") { LicencesView() }
                    #if DEBUG
                    NavigationLink("Design gallery") { DesignGalleryView() }
                    #endif
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $exportFile) { file in
                ActivityView(url: file.url).ignoresSafeArea()
            }
            .alert("Settings", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(notice ?? "")
            }
        }
    }

    // MARK: Bindings

    private var currentCurrency: String { model.data?.appSettings.baseCurrencyCode ?? "USD" }

    /// A stored code outside the standard list still has to be selectable.
    private var currencyOptions: [String] {
        Self.currencies.contains(currentCurrency) ? Self.currencies : [currentCurrency] + Self.currencies
    }

    private var currencyBinding: Binding<String> {
        Binding(
            get: { currentCurrency },
            set: { code in Task { await model.setBaseCurrency(code) } })
    }

    private func currencyLabel(_ code: String) -> String {
        if let name = Locale.current.localizedString(forCurrencyCode: code) { return "\(code) – \(name)" }
        return code
    }

    private var lockBinding: Binding<Bool> {
        Binding(
            get: { model.data?.appSettings.appLockEnabled == true },
            set: { enable in
                if enable {
                    Task {
                        switch await DeviceAuth.authenticate(reason: "Turn on App Lock") {
                        case .success: await model.setAppLockEnabled(true)
                        case .failed: break
                        case .unavailable: notice = "Set a passcode in the Settings app to use App Lock."
                        }
                    }
                } else {
                    Task { await model.setAppLockEnabled(false) }
                }
            })
    }

    // MARK: Export and version

    private func export() {
        do {
            exportFile = ExportFile(url: try model.exportCSV())
        } catch {
            notice = "Couldn't create the export file. \(error.localizedDescription)"
        }
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

private struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}

private struct ActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
