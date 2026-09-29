import BudgieCore
import SwiftUI

/// Home's cash-flow hero (`_HeroCashFlow`, spending_page.dart:1093-1217):
/// the "CASH FLOW" eyebrow, the month's `income - expenses` as a rolling
/// odometer (never a minus sign; danger when negative), the in/out subline
/// and the status caption.
struct HomeHero: View {
    let income: Double
    let expenses: Double
    let formatter: MoneyFormatter

    /// `rowSubtitle` at 14 (the subline).
    private static let subline = TextSpec(face: .gabaritoRegular, size: 14, height: 1.25, relativeTo: .subheadline)
    /// `caption` with w700 (the status).
    private static let status = TextSpec(face: .gabaritoBold, size: 13, tracking: -0.1, height: 1.4, relativeTo: .footnote)

    var body: some View {
        let cashFlow = income - expenses
        let isNegative = cashFlow < 0
        let glowColor = isNegative ? BudgieColor.danger : BudgieColor.accent
        let amountColor = isNegative ? BudgieColor.danger : BudgieColor.textPrimary
        let amountLabel = formatter.format(abs(cashFlow))
        let statusLabel = cashFlow > 0 ? "SAVED THIS MONTH" : cashFlow < 0 ? "SHORT THIS MONTH" : "BREAKING EVEN"

        VStack(spacing: 0) {
            Text("CASH FLOW")
                .textStyle(.eyebrow)
                .foregroundStyle(BudgieColor.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) {
                Group {
                    if formatter.hideBalances {
                        // Dots have no digits to roll.
                        Text(amountLabel)
                            .textStyle(.hero)
                            .foregroundStyle(amountColor)
                            .textGlow(glowColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    } else {
                        RollingAmount(text: amountLabel, color: amountColor, glow: glowColor)
                    }
                }
                .padding(.top, 10)
                Text("\(formatter.format(income, decimalDigits: 0)) in   \u{00B7}   \(formatter.format(expenses, decimalDigits: 0)) out")
                    .textStyle(Self.subline)
                    .foregroundStyle(BudgieColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                Text(statusLabel)
                    .textStyle(Self.status)
                    .foregroundStyle(isNegative ? BudgieColor.danger : BudgieColor.accent)
                    .padding(.top, 4)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                isNegative ? "Cash flow, \(amountLabel) short this month." : "Cash flow, \(amountLabel) this month.")
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 36, leading: 24, bottom: 0, trailing: 24))
    }
}

// MARK: - Rolling odometer

/// The hero amount as an odometer (`AnimatedDigitWidget`, animated_digit
/// 3.3.2): one cell per character of the formatted label, so the currency
/// prefix/suffix and separators come from the formatter. Each digit is a
/// clipped vertical reel that only rolls forward (upward), taking
/// `c > n ? 10 - c + n : n - c` steps, all cells together over 900ms
/// easeInOut; an unchanged digit stays still. On first appearance every
/// digit rolls up from 0, and when the label's shape (length or any
/// non-digit character) changes the cells are rebuilt and roll from 0 while
/// the row eases to its new width. The
/// halo is a blurred copy of the whole label underneath, because the cells
/// clip. Rolls the rounded label (Flutter's widget truncates the fraction,
/// so its digits can be 0.01 off the halo and semantics). Scales down as a
/// whole when it is wider than the space. Reduce Motion shows the digits
/// without rolling.
struct RollingAmount: View {
    let text: String
    let color: Color
    let glow: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: TextSpec.hero.relativeTo) private var fontSize = TextSpec.hero.size
    @State private var natural: CGSize = .zero
    @State private var available: CGFloat = 0
    @State private var rowWidth: CGFloat?

    var body: some View {
        let rowHeight = TextSpec.hero.lineHeight(scaledSize: fontSize)
        let skeleton = Self.skeleton(of: text)
        let animation: Animation? = reduceMotion ? nil : Motion.easeInOut(0.9)
        let measured = natural.width > 0 && available > 0
        let scale = measured ? min(1, available / natural.width) : 1

        ZStack {
            // `textGlow` (blur 48; alpha .45 dark, .18 light) is a shadow,
            // i.e. a blurred copy of the glyphs in the glow colour; a
            // shadow of clear text would paint nothing.
            Text(text)
                .textStyle(.hero)
                .foregroundStyle(glow.opacity(scheme == .dark ? 0.45 : 0.45 * 0.4))
                .blur(radius: 24)
            HStack(spacing: 0) {
                ForEach(Self.cells(of: text, skeleton: skeleton), id: \.id) { cell in
                    Group {
                        if let digit = cell.digit {
                            DigitReel(digit: digit, rowHeight: rowHeight, animation: animation)
                        } else {
                            Text(String(cell.character))
                                .textStyle(.hero)
                                .fixedSize()
                                .frame(height: rowHeight)
                        }
                    }
                    .transition(.identity)
                }
            }
            .foregroundStyle(color)
            .fixedSize()
            .onGeometryChangeCompat { size in
                // Flutter's `AnimatedSize`: a rebuilt row eases to its new
                // width, clipped, over the same 900ms.
                if rowWidth == nil || animation == nil {
                    rowWidth = size.width
                } else if rowWidth != size.width {
                    withAnimation(animation) { rowWidth = size.width }
                }
            }
            .frame(width: rowWidth)
            // Clips sideways only: a "$" may reach past the 1.0 line box.
            .mask { Rectangle().padding(.vertical, -rowHeight / 2) }
        }
        .fixedSize()
        .onGeometryChangeCompat { natural = $0 }
        .scaleEffect(scale)
        .frame(width: measured ? natural.width * scale : nil, height: measured ? natural.height * scale : nil)
        .frame(minWidth: 0, maxWidth: .infinity)
        .onGeometryChangeCompat { available = $0.width }
        // Each reel is an 11-row strip that `clipped()` hides but does not
        // stop from hit-testing: offset by its digit, a strip reaches up over
        // the month pill and wheel and swallows their touches.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Cell {
        let id: String
        let character: Character
        let digit: Int?
    }

    /// The label with every ASCII digit replaced by "0": cells are rebuilt
    /// (and roll from 0) only when this changes.
    static func skeleton(of text: String) -> String {
        String(text.map { $0.isASCII && $0.isNumber ? "0" : $0 })
    }

    private static func cells(of text: String, skeleton: String) -> [Cell] {
        text.enumerated().map { index, character in
            let digit = character.isASCII ? character.wholeNumberValue : nil
            return Cell(id: "\(skeleton)#\(index)", character: character, digit: digit)
        }
    }
}

/// One odometer digit: a strip of 0-9 plus a trailing 0, clipped to one
/// row and offset by a monotonic `position` (mod 10), so rolling past 9
/// wraps seamlessly. Only the strip's transform animates.
private struct DigitReel: View {
    let digit: Int
    let rowHeight: CGFloat
    let animation: Animation?

    @State private var position: Double

    init(digit: Int, rowHeight: CGFloat, animation: Animation?) {
        self.digit = digit
        self.rowHeight = rowHeight
        self.animation = animation
        // A new reel starts at 0 and rolls up on appear; without animation
        // it starts at its digit so nothing flashes.
        _position = State(initialValue: animation == nil ? Double(digit) : 0)
    }

    var body: some View {
        Text(verbatim: "0")
            .textStyle(.hero)
            .fixedSize()
            .hidden()
            .frame(height: rowHeight)
            .overlay(alignment: .top) {
                VStack(spacing: 0) {
                    ForEach(0..<11, id: \.self) { row in
                        Text(verbatim: String(row % 10))
                            .textStyle(.hero)
                            .fixedSize()
                            .frame(height: rowHeight)
                    }
                }
                .modifier(ReelOffset(position: position, rowHeight: rowHeight))
            }
            .clipped()
            .onAppear { roll(to: digit) }
            .onChange(of: digit) { _, new in roll(to: new) }
    }

    /// Forward only: `c > n ? 10 - c + n : n - c` steps.
    private func roll(to new: Int) {
        let current = Int(position.rounded()) % 10
        let steps = (new - current + 10) % 10
        guard steps > 0 else { return }
        withAnimation(animation) { position += Double(steps) }
    }
}

/// Moves the digit strip up by `position` rows (mod 10); animatable, so a
/// roll interpolates only this transform.
private struct ReelOffset: GeometryEffect {
    var position: Double
    let rowHeight: CGFloat

    nonisolated var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    nonisolated func effectValue(size: CGSize) -> ProjectionTransform {
        let rows = position.truncatingRemainder(dividingBy: 10)
        return ProjectionTransform(CGAffineTransform(translationX: 0, y: -rows * rowHeight))
    }
}
