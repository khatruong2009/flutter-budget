import Foundation
import Testing

@testable import BudgieCore

/// The onboarding flag as the Flutter gate reads and writes it
/// (onboarding_tutorial.dart `_loadCompletionState` / `_completeTutorial`).
@Suite("Onboarding flag")
struct OnboardingFlagTests {
    @Test("missing, false or another type shows the tour; only a bool true completes it")
    func read() {
        #expect(!OnboardingFlag.isCompleted(InMemoryPreferences()))
        let key = PreferenceKey.onboardingCompleted
        #expect(key == "flutter.onboarding_completed")
        #expect(!OnboardingFlag.isCompleted(InMemoryPreferences([key: .bool(false)])))
        #expect(OnboardingFlag.isCompleted(InMemoryPreferences([key: .bool(true)])))
        for other: PreferenceValue in [.string("true"), .int(1), .double(1), .stringList(["true"])] {
            #expect(!OnboardingFlag.isCompleted(InMemoryPreferences([key: other])), "\(other)")
        }
        // The bare Dart key (no plugin prefix) is not the flag.
        #expect(!OnboardingFlag.isCompleted(InMemoryPreferences(["onboarding_completed": .bool(true)])))
    }

    @Test("complete writes bool true under the plugin key; reset removes it")
    func write() {
        let preferences = InMemoryPreferences([PreferenceKey.themeMode: .string("dark")])
        OnboardingFlag.markCompleted(preferences)
        #expect(preferences.all == [PreferenceKey.onboardingCompleted: .bool(true), PreferenceKey.themeMode: .string("dark")])
        OnboardingFlag.markCompleted(preferences)
        #expect(OnboardingFlag.isCompleted(preferences))
        OnboardingFlag.reset(preferences)
        #expect(preferences.all == [PreferenceKey.themeMode: .string("dark")])
        #expect(!OnboardingFlag.isCompleted(preferences))
    }

    @Test("in NSUserDefaults the flag is a CFBoolean (what the Flutter plugin reads as bool)")
    func userDefaults() throws {
        let suite = "budgie.tests.onboarding.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = UserDefaultsPreferences(defaults: defaults, domainName: suite)
        #expect(!OnboardingFlag.isCompleted(preferences))
        OnboardingFlag.markCompleted(preferences)
        let raw = try #require(defaults.persistentDomain(forName: suite)?[PreferenceKey.onboardingCompleted] as? NSNumber)
        #expect(CFGetTypeID(raw) == CFBooleanGetTypeID() && raw.boolValue)
        #expect(OnboardingFlag.isCompleted(preferences))
        OnboardingFlag.reset(preferences)
        #expect(defaults.persistentDomain(forName: suite)?[PreferenceKey.onboardingCompleted] == nil)
        #expect(!OnboardingFlag.isCompleted(preferences))
        // An int 1 (what `defaults write -int 1` stores) is not a bool.
        // (Removed first: NSNumber treats @YES and @1 as equal, so setting
        // 1 over true is skipped as unchanged.)
        for number in [NSNumber(value: 1 as Int), NSNumber(value: 1.0 as Double)] {
            defaults.set(number, forKey: PreferenceKey.onboardingCompleted)
            #expect(!OnboardingFlag.isCompleted(preferences))
            // Completing the tour replaces the number with a real bool (a
            // plain set would be skipped as unchanged).
            OnboardingFlag.markCompleted(preferences)
            let replaced = try #require(defaults.persistentDomain(forName: suite)?[PreferenceKey.onboardingCompleted] as? NSNumber)
            #expect(CFGetTypeID(replaced) == CFBooleanGetTypeID(), "\(number)")
            #expect(OnboardingFlag.isCompleted(preferences), "\(number)")
            OnboardingFlag.reset(preferences)
        }
    }
}
