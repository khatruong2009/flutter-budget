/// Dart's `double.toString()`, which is also how `jsonEncode` writes doubles.
///
/// Dart prints the shortest digit string that round-trips (like ECMAScript
/// `Number.prototype.toString`), uses exponent form when the decimal exponent
/// is below -6 or at least 21, and appends `.0` to integral results. Examples
/// (verified against Dart, see Fixtures/logic/numbers.json):
/// `1.0`, `100.0`, `0.30000000000000004`, `0.000001`, `1e-7`,
/// `100000000000000000000.0`, `1e+21`, `-0.0`, `5e-324`.
public enum DartDouble {
    public static func format(_ value: Double) -> String {
        precondition(value.isFinite, "Dart cannot print non-finite doubles in JSON")
        if value == 0 { return value.sign == .minus ? "-0.0" : "0.0" }
        let negative = value < 0
        let (digits, pointPosition) = shortestDigits(value.magnitude)
        let body = ecmaScriptString(digits: digits, n: pointPosition)
        return (negative ? "-" : "") + body
    }

    /// Shortest round-trip decimal digits of a positive finite double, and
    /// `n` such that value = 0.d1d2...dk * 10^n.
    ///
    /// Swift's `description` already produces the shortest round-trip digits
    /// (SwiftDtoa); only its layout differs from Dart's, so it is re-laid out.
    static func shortestDigits(_ value: Double) -> (digits: [UInt8], n: Int) {
        let text = value.description  // e.g. "1.2345e-07", "123.45", "1e+21"
        var mantissa = Substring(text)
        var exponent = 0
        if let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            mantissa = text[..<e]
            exponent = Int(text[text.index(after: e)...])!
        }
        var digits: [UInt8] = []
        var pointIndex: Int? = nil
        for character in mantissa {
            if character == "." {
                pointIndex = digits.count
            } else {
                digits.append(character.asciiValue! - UInt8(ascii: "0"))
            }
        }
        var n = (pointIndex ?? digits.count) + exponent
        // Strip leading zeros (e.g. "0.0001") and trailing zeros ("100.0").
        while digits.first == 0 {
            digits.removeFirst()
            n -= 1
        }
        while digits.last == 0 {
            digits.removeLast()
        }
        return (digits, n)
    }

    /// ECMAScript Number::toString layout, plus Dart's `.0` suffix.
    static func ecmaScriptString(digits: [UInt8], n: Int) -> String {
        let k = digits.count
        let text = digits.map { Character(Unicode.Scalar($0 + UInt8(ascii: "0"))) }
        if k <= n && n <= 21 {
            return String(text) + String(repeating: "0", count: n - k) + ".0"
        }
        if 0 < n && n <= 21 {
            return String(text[0..<n]) + "." + String(text[n...])
        }
        if -6 < n && n <= 0 {
            return "0." + String(repeating: "0", count: -n) + String(text)
        }
        let e = n - 1
        let exponent = e < 0 ? "-\(-e)" : "+\(e)"
        if k == 1 {
            return String(text) + "e" + exponent
        }
        return String(text[0]) + "." + String(text[1...]) + "e" + exponent
    }
}
