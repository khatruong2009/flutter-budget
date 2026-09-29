import UIKit

/// The bundled typefaces (spec 01 section 4). The TTFs are static, one file
/// per weight, and each weight has its own family name, so a weight is
/// chosen by PostScript name, never by `.weight()` or `.bold()` (that would
/// synthesise a fake bold).
enum BudgieFont: String, CaseIterable {
    case gabaritoRegular = "Gabarito-Regular"
    case gabaritoMedium = "Gabarito-Medium"
    case gabaritoSemiBold = "Gabarito-SemiBold"
    case gabaritoBold = "Gabarito-Bold"
    case gabaritoExtraBold = "Gabarito-ExtraBold"
    case monoRegular = "SplineSansMono-Regular"
    case monoMedium = "SplineSansMono-Medium"
    case monoSemiBold = "SplineSansMono-SemiBold"

    var postScriptName: String { rawValue }

    /// Every font registered through `UIAppFonts`. A missing one silently
    /// falls back to the system font, so a test checks this.
    static var missing: [BudgieFont] {
        allCases.filter { UIFont(name: $0.postScriptName, size: 12) == nil }
    }
}
