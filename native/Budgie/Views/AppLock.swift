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
    /// Whether this launch has been unlocked. The modifier is created when
    /// the data becomes ready, so a fresh `false` means "locked at launch".
    @State private var unlocked = false
    @State private var backgroundedAt: ContinuousClock.Instant?

    private var enabled: Bool { model.data?.appSettings.appLockEnabled == true }
    private var timeout: Int { model.data?.appSettings.autoLockTimeoutSeconds ?? 0 }

    func body(content: Content) -> some View {
        let locked = enabled && !unlocked
        content
            .overlay {
                if locked {
                    LockScreen { unlocked = true }
                } else if enabled && scenePhase != .active {
                    PrivacyCover()
                }
            }
            .onChange(of: enabled) { _, isOn in
                // Turning the lock on (Settings authenticated first) must not
                // lock the session that is already open.
                if isOn { unlocked = true }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    backgroundedAt = .now
                case .active:
                    if let since = backgroundedAt, since.duration(to: .now) >= .seconds(max(timeout, 0)) {
                        unlocked = false
                    }
                    backgroundedAt = nil
                default:
                    break
                }
            }
    }
}

private struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("logo")
                    .resizable().scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                Text("Budgie").font(.title2.weight(.semibold))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LockScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    let onUnlock: () -> Void
    @State private var attempted = false
    @State private var authenticating = false
    @State private var message: String?

    var body: some View {
        ZStack {
            PrivacyCover()
            VStack {
                Spacer()
                if let message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 32).padding(.bottom, 12)
                }
                Button {
                    unlock()
                } label: {
                    Text("Unlock").font(.headline).frame(maxWidth: 240)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(authenticating)
                .padding(.bottom, 64)
            }
        }
        .tint(Theme.accent)
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
        message = nil
        Task {
            let outcome = await DeviceAuth.authenticate(reason: "Unlock Budgie")
            authenticating = false
            switch outcome {
            case .success:
                onUnlock()
            case .failed:
                break
            case .unavailable(let reason):
                // No passcode: there is nothing to lock against, and keeping
                // the data hidden forever would lock the owner out.
                message = reason
                onUnlock()
            }
        }
    }
}
