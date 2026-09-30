import SwiftUI

// The Settings page's building blocks (settings_page.dart:1064-1310).

/// `_BrandCard` (sp:1064-1131): a non-interactive GlowCard with the accent
/// wash and a 30% accent border, the 52pt glowing mark, "Budgie" and the
/// tagline.
struct SettingsBrandCard: View {
    /// `cardTitle` at 18 / w800, tracking -0.3.
    private static let titleText = TextSpec(face: .gabaritoExtraBold, size: 18, tracking: -0.3, height: 1.25, relativeTo: .headline)
    /// `rowSubtitle` at 13.
    private static let taglineText = TextSpec(face: .gabaritoRegular, size: 13, height: 1.25, relativeTo: .footnote)

    var body: some View {
        GlowCard(
            fill: AnyShapeStyle(
                LinearGradient(
                    colors: [BudgieColor.brandCardWash, BudgieColor.card], startPoint: .topLeading, endPoint: .bottomTrailing)),
            border: BudgieColor.accent.opacity(0.3)
        ) {
            HStack(spacing: 16) {
                Image("logo")
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .glow(BudgieColor.accent, blur: 24, alpha: 0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Budgie")
                        .textStyle(Self.titleText)
                        .foregroundStyle(BudgieColor.textPrimary)
                    Text("Make every dollar count")
                        .textStyle(Self.taglineText)
                        .foregroundStyle(BudgieColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budgie, Make every dollar count")
    }
}

/// `_SectionEyebrow` (sp:1134-1152): mono eyebrow in the tertiary colour,
/// inset 24, 28 above.
struct SettingsEyebrow: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(.eyebrow)
            .foregroundStyle(BudgieColor.textTertiary)
            // One line: at accessibility sizes "PERSONALIZATION" would
            // otherwise break mid-word.
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(EdgeInsets(top: 28, leading: 24, bottom: 0, trailing: 24))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Material Symbols draw a 20pt icon inside ~2pt of padding, so its glyphs
/// look smaller than an SF Symbol at 20; these point sizes match the
/// Settings screenshots' glyphs (most ~15-17pt across; the file arrows 13).
enum SettingsGlyph {
    static let standard: CGFloat = 15
    /// Glyphs that fill their Material box (language, lock, timer, info).
    static let full: CGFloat = 17
    /// file_download / file_upload, drawn small in their box.
    static let small: CGFloat = 13
}

/// `_SettingsRow` (sp:1227-1310): 40pt tile (the colour at 14% unless
/// `tile` overrides it), title and a one-line subtitle (two at accessibility
/// text sizes), then the trailing view; padding 14 x 12. With `action` the
/// whole row is a button (light
/// haptic, no visible press state, VoiceOver "title, subtitle"); without
/// one it is plain. While `busy` VoiceOver hears `busyLabel` ("Exporting",
/// "Importing", "Restoring") for the subtitle.
struct SettingsRow<Trailing: View>: View {
    let symbol: String
    let color: Color
    var tile: Color? = nil
    var iconSize = SettingsGlyph.standard
    let title: String
    let subtitle: String
    var busy = false
    var busyLabel = "Exporting"
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    @State private var taps = 0

    var body: some View {
        let row = HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color, iconSize: iconSize, background: tile ?? color.opacity(0.14))
            SettingsRowText(title: title, subtitle: subtitle, subtitleLines: 1)
            trailing()
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())

        if let action {
            Button {
                taps += 1
                action()
            } label: {
                row
            }
            .buttonStyle(PressScaleStyle(scale: 1))
            .sensoryFeedback(.impact(weight: .light), trigger: taps)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(subtitle)
            .accessibilityAddTraits(.isButton)
        } else {
            row
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(title)
                .accessibilityValue(busy ? busyLabel : subtitle)
        }
    }
}

extension SettingsRow where Trailing == SettingsChevron {
    /// A row that opens something: the chevron, or the spinner while `busy`.
    init(
        symbol: String, color: Color, tile: Color? = nil, iconSize: CGFloat = SettingsGlyph.standard, title: String,
        subtitle: String, busy: Bool = false, busyLabel: String = "Exporting", action: (() -> Void)?
    ) {
        self.init(
            symbol: symbol, color: color, tile: tile, iconSize: iconSize, title: title, subtitle: subtitle, busy: busy,
            busyLabel: busyLabel, action: action,
            trailing: { SettingsChevron(busy: busy) })
    }
}

/// A row whose only control is its switch (App lock, Hide balances): the
/// row body is not tappable (Flutter's `onTap: null`). Flutter's
/// `Switch.adaptive` is a CupertinoSwitch in systemGreen, so the app-wide
/// accent tint is overridden. VoiceOver reads the switch as the title with
/// the subtitle as its hint.
struct SettingsToggleRow: View {
    let symbol: String
    let color: Color
    var iconSize = SettingsGlyph.standard
    let title: String
    let subtitle: String
    let isOn: Binding<Bool>
    var identifier: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color, iconSize: iconSize, background: color.opacity(0.14))
            SettingsRowText(title: title, subtitle: subtitle, subtitleLines: 1)
                .accessibilityHidden(true)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(.green)
                .accessibilityHint(subtitle)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
    }
}

/// `_ThemeRow` (sp:1156-1224): the moon tile, "Theme" with a subtitle that
/// wraps (no line limit), and the Light | Dark | Auto pills. When the pills
/// leave the text under 80pt (large text sizes) they move under it.
struct SettingsThemeRow: View {
    @Binding var selection: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                tile
                text.frame(minWidth: 80, idealWidth: 80, maxWidth: .infinity)
                pills
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    tile
                    text
                }
                pills
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
    }

    private var tile: some View {
        IconTile(
            symbol: "moon", color: BudgieColor.accent, iconSize: SettingsGlyph.standard,
            background: BudgieColor.accent.opacity(0.14))
    }

    private var text: some View {
        SettingsRowText(title: "Theme", subtitle: "Light, dark, or match device", subtitleLines: nil)
            .accessibilityElement(children: .combine)
    }

    /// Capped at AX2 so the three pills still fit the card's width.
    private var pills: some View {
        SegmentedPills(items: ["Light", "Dark", "Auto"], selection: $selection)
            .fixedSize()
            .dynamicTypeSize(...DynamicTypeSize.accessibility2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Theme mode")
    }
}

/// Title (`rowTitle`) over the subtitle (`rowSubtitle`, secondary), 2 apart.
/// A one-line subtitle gets a second line at accessibility text sizes,
/// where one line keeps only its first word or two (Flutter clips it).
private struct SettingsRowText: View {
    let title: String
    let subtitle: String
    let subtitleLines: Int?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .textStyle(.rowTitle)
                .foregroundStyle(BudgieColor.textPrimary)
            Text(subtitle)
                .textStyle(.rowSubtitle)
                .foregroundStyle(BudgieColor.textSecondary)
                .lineLimit(subtitleLines == 1 && typeSize.isAccessibilitySize ? 2 : subtitleLines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: subtitleLines == nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The trailing `chevron_right` (20pt, tertiary), or a 20pt progress
/// indicator in the accent while the row's action runs (Flutter: a ring in
/// the text colour).
struct SettingsChevron: View {
    var busy = false

    var body: some View {
        if busy {
            ProgressView()
                .controlSize(.small)
                .tint(BudgieColor.accent)
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
        } else {
            // Material's chevron is ~6 x 10 inside its 20pt box.
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(BudgieColor.textTertiary)
                .frame(width: 20)
                .accessibilityHidden(true)
        }
    }
}
