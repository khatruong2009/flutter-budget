import LocalAuthentication
import SwiftUI

/// Device-owner authentication shared by the lock screen and the Settings
/// toggle. Touches no model state.
enum DeviceAuth {
    enum Outcome: Equatable {
        case success
        case failed
        /// The device has no passcode, so there is nothing to authenticate with.
        case unavailable(String)
    }

    /// "Face ID", "Touch ID", "Optic ID", or "Passcode" when the device has no biometry.
    static var biometryName: String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    static func authenticate(reason: String) async -> Outcome {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return .unavailable(error?.localizedDescription ?? "This device can't authenticate.")
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) ? .success : .failed
        } catch {
            return .failed
        }
    }
}

extension View {
    /// UI_SPEC "App lock": privacy cover and lock screen over the content.
    /// Cosmetic only; the model's bootstrap and saves never depend on it.
    func appLock() -> some View { modifier(AppLockModifier()) }
}

private struct AppLockModifier: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var backgroundedAt: ContinuousClock.Instant?
    /// Settings' enable prompt made the scene inactive: no cover until the
    /// scene is active again (or goes to the background).
    @State private var coverHeld = false

    private var enabled: Bool { model.data?.appSettings.appLockEnabled == true }
    private var timeout: Int { model.data?.appSettings.autoLockTimeoutSeconds ?? 0 }

    func body(content: Content) -> some View {
        content
            // While locked VoiceOver reaches only the lock screen, not the
            // tabs or the tour beneath it (Flutter's `ExcludeSemantics`).
            .accessibilityHidden(model.isLocked)
            .overlay {
                if model.isLocked {
                    LockScreen { model.markUnlocked() }
                } else if enabled && scenePhase != .active && !coverHeld {
                    PrivacyCover()
                }
            }
            .onChange(of: enabled) { _, isOn in
                // Turning the lock on (Settings authenticated first) must not
                // lock the session that is already open.
                if isOn { model.markUnlocked() }
            }
            .onChange(of: model.isEnablingAppLock) { _, enabling in
                if enabling {
                    coverHeld = true
                } else if scenePhase == .active {
                    coverHeld = false
                }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    backgroundedAt = .now
                    coverHeld = false
                case .active:
                    if !model.isEnablingAppLock { coverHeld = false }
                    if let since = backgroundedAt, since.duration(to: .now) >= .seconds(max(timeout, 0)) {
                        model.relock()
                    }
                    backgroundedAt = nil
                default:
                    break
                }
            }
    }
}

/// The app-switcher cover (`_AppSwitcherPrivacyCover`): opaque #0A0A12 in
/// both themes, 72pt mark, "Budgie", "App preview hidden".
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color(hex: 0x0A0A12).ignoresSafeArea()
            VStack(spacing: 0) {
                Image("logo").resizable().scaledToFit().frame(width: 72, height: 72)
                Text("Budgie")
                    .textStyle(.headingLarge)
                    .foregroundStyle(Color(hex: 0xF2F2FA))
                    .padding(.top, Metrics.spacingM)
                Text("App preview hidden")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(Color(hex: 0x9A9AB5))
                    .padding(.top, Metrics.spacingXS)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The lock screen (`_LockScreen`), in the redesign tokens: lock symbol,
/// "Budgie is locked", the reason or the last error, and an Unlock button.
struct LockScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    let onUnlock: () -> Void
    @State private var attempted = false
    @State private var authenticating = false
    @State private var error: String?
    @State private var biometry = DeviceAuth.biometryName

    var body: some View {
        ZStack {
            BudgieColor.background.ignoresSafeArea()
            VStack(spacing: 0) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(BudgieColor.accent)
                    .accessibilityHidden(true)
                Text("Budgie is locked")
                    .textStyle(.headingLarge)
                    .foregroundStyle(BudgieColor.textPrimary)
                    .padding(.top, Metrics.spacingL)
                    .accessibilityAddTraits(.isHeader)
                Text(error ?? "Authenticate to view your financial data.")
                    .textStyle(.bodyMedium)
                    .foregroundStyle(error == nil ? BudgieColor.textSecondary : BudgieColor.danger)
                    .multilineTextAlignment(.center)
                    .padding(.top, Metrics.spacingS)
                PillButton(
                    title: authenticating ? "Authenticating…" : "Unlock",
                    symbol: biometry == "Face ID" ? "faceid" : biometry == "Touch ID" ? "touchid" : "lock.open",
                    filled: true, height: 52
                ) {
                    unlock()
                }
                .disabled(authenticating)
                .padding(.top, Metrics.spacingL)
            }
            .frame(maxWidth: 360)
            .padding(Metrics.spacingXL)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // Evaluating while the scene is inactive fails, so wait for active.
        // Auto-attempt once; the Unlock button retries.
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, !attempted else { return }
            attempted = true
            unlock()
        }
    }

    private func unlock() {
        guard !authenticating else { return }
        authenticating = true
        error = nil
        Task {
            let outcome = await DeviceAuth.authenticate(reason: "Unlock Budgie to view your financial data")
            authenticating = false
            switch outcome {
            case .success:
                onUnlock()
            case .failed:
                error = "Authentication was not completed."
            case .unavailable:
                // No passcode: there is nothing to lock against, and keeping
                // the data hidden forever would lock the owner out.
                onUnlock()
            }
        }
    }
}
