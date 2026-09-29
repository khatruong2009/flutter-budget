import Foundation

/// One entry of a Settings choice sheet: the stored value and its label.
public struct SettingsChoice<Value: Hashable & Sendable>: Hashable, Sendable {
    public let value: Value
    public let label: String
}

/// The Settings page's fixed lists and subtitle labels
/// (`settings_page.dart`: `_supportedCurrencies`, `_supportedLocales`,
/// `_chooseLockTimeout`, `_currencyLabel`, `_localeLabel`,
/// `_lockTimeoutLabel`). Fixed English copy, checked against the real page
/// (Fixtures/settings/labels.json).
public enum SettingsOptions {
    /// sp:1038-1050, in sheet order; the sheet shows the bare name.
    public static let currencies: [SettingsChoice<String>] = [
        ("USD", "US Dollar"), ("CAD", "Canadian Dollar"), ("EUR", "Euro"), ("GBP", "British Pound"),
        ("AUD", "Australian Dollar"), ("JPY", "Japanese Yen"), ("CNY", "Chinese Yuan"), ("INR", "Indian Rupee"),
        ("KRW", "South Korean Won"), ("MXN", "Mexican Peso"), ("BRL", "Brazilian Real"),
    ].map { SettingsChoice(value: $0.0, label: $0.1) }

    /// sp:944-961 and 1052-1061: "Match device" (stored as null) first.
    public static let locales: [SettingsChoice<String?>] =
        [SettingsChoice(value: nil, label: "Match device")]
        + [
            ("en_US", "English (United States)"), ("en_CA", "English (Canada)"), ("en_GB", "English (United Kingdom)"),
            ("en_AU", "English (Australia)"), ("de_DE", "German (Germany)"), ("fr_FR", "French (France)"),
            ("es_ES", "Spanish (Spain)"), ("ja_JP", "Japanese (Japan)"),
        ].map { SettingsChoice(value: $0.0, label: $0.1) }

    /// sp:967-973, seconds.
    public static let lockDelays: [SettingsChoice<Int>] = [
        (0, "Immediately"), (30, "30 seconds"), (60, "1 minute"), (300, "5 minutes"), (900, "15 minutes"),
    ].map { SettingsChoice(value: $0.0, label: $0.1) }

    /// `_currencyLabel` (sp:919): "US Dollar (USD)"; an unlisted code shows
    /// itself twice ("CHF (CHF)").
    public static func currencyLabel(_ code: String) -> String {
        "\(currencies.first { $0.value == code }?.label ?? code) (\(code))"
    }

    /// `_localeLabel` (sp:922): "Match device" for nil, else the label, or
    /// the stored string when it is not listed.
    public static func localeLabel(_ locale: String?) -> String {
        guard let locale else { return "Match device" }
        return locales.first { $0.value == locale }?.label ?? locale
    }

    /// `_lockTimeoutLabel` (sp:925-929), quirks included: "1 seconds", and
    /// whole minutes truncated with a plural for everything but 60
    /// ("1 minutes" for 61-119).
    public static func lockTimeoutLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "Immediately" }
        if seconds < 60 { return "\(seconds) seconds" }
        return "\(seconds / 60) minute\(seconds == 60 ? "" : "s")"
    }
}

/// What an `AppSettingsProvider` setter does with a value.
public enum SettingsUpdate: Hashable, Sendable {
    /// Dart returns early for an invalid value: nothing changes or is written.
    case rejected
    /// Dart returns early for the current value: nothing is written.
    case unchanged
    /// Memory changed; mirror `value` under the preference `key` (nil
    /// removes it), then write the `appSettings` section.
    case write(key: String, value: PreferenceValue?)
}

extension AppSettings {
    /// `setBaseCurrencyCode` (asp:58-67): trimmed and uppercased as Dart
    /// does; rejected unless 3 UTF-16 code units long.
    public mutating func setBaseCurrencyCode(_ value: String) -> SettingsUpdate {
        let normalized = DartString.uppercase(DartString.trim(value))
        guard normalized.utf16.count == 3 else { return .rejected }
        guard !DartString.equal(normalized, baseCurrencyCode) else { return .unchanged }
        baseCurrencyCode = normalized
        return .write(key: PreferenceKey.baseCurrencyCode, value: .string(normalized))
    }

    /// `setLocaleOverride` (asp:69-82): trimmed, empty is nil (the mirror is
    /// removed). No guard: Dart writes even an unchanged value.
    public mutating func setLocaleOverride(_ value: String?) -> SettingsUpdate {
        let normalized = value.map(DartString.trim)
        localeOverride = normalized?.isEmpty == false ? normalized : nil
        return .write(key: PreferenceKey.localeOverride, value: localeOverride.map { .string($0) })
    }

    /// `setAppLockEnabled` (asp:84-91).
    public mutating func setAppLockEnabled(_ value: Bool) -> SettingsUpdate {
        guard value != appLockEnabled else { return .unchanged }
        appLockEnabled = value
        return .write(key: PreferenceKey.appLockEnabled, value: .bool(value))
    }

    /// `setAutoLockTimeoutSeconds` (asp:93-100): negative values rejected.
    public mutating func setAutoLockTimeoutSeconds(_ value: Int) -> SettingsUpdate {
        guard value >= 0 else { return .rejected }
        guard value != autoLockTimeoutSeconds else { return .unchanged }
        autoLockTimeoutSeconds = value
        return .write(key: PreferenceKey.autoLockTimeoutSeconds, value: .int(Int64(value)))
    }

    /// `setHideBalances` (asp:102-110).
    public mutating func setHideBalances(_ value: Bool) -> SettingsUpdate {
        guard value != hideBalances else { return .unchanged }
        hideBalances = value
        return .write(key: PreferenceKey.hideBalances, value: .bool(value))
    }
}
