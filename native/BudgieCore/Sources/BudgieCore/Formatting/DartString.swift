import Foundation

/// Dart `String` operations whose Swift counterparts differ.
///
/// Dart strings are sequences of UTF-16 code units: `==`, `contains`,
/// `startsWith` and `compareTo` compare code units, with no canonical
/// equivalence (Swift `String` compares by grapheme and treats "é" and
/// "e\u{301}" as equal).
public enum DartString {
    /// Dart `String.trim`: Unicode White_Space plus U+FEFF (Swift's
    /// `.whitespacesAndNewlines` has no U+FEFF).
    public static func trim(_ text: String) -> String {
        let scalars = text.unicodeScalars
        guard let start = scalars.firstIndex(where: { !isWhitespace($0) }) else { return "" }
        let end = scalars.lastIndex(where: { !isWhitespace($0) })!
        return String(scalars[start...end])
    }

    /// Dart's `trim` whitespace set (`String.trim` docs).
    public static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF:
            return true
        default:
            return false
        }
    }

    /// Dart `String.toLowerCase`: the simple (one-to-one) Unicode lowercase
    /// mapping of each scalar, no locale and no final-sigma rule. The only
    /// unconditional full mapping that differs is U+0130, which Dart maps to
    /// plain "i" (Swift's `lowercased()` gives "i" + U+0307).
    public static func lowercase(_ text: String) -> String {
        var result = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if scalar.value == 0x130 {
                result.append("i")
                continue
            }
            let mapped = scalar.properties.lowercaseMapping.unicodeScalars
            if mapped.count == 1 { result.append(contentsOf: mapped) } else { result.append(scalar) }
        }
        return String(result)
    }

    /// Dart `a == b`.
    public static func equal(_ a: String, _ b: String) -> Bool {
        a.utf16.elementsEqual(b.utf16)
    }

    /// Dart `text.startsWith(prefix)`.
    public static func hasPrefix(_ text: String, _ prefix: String) -> Bool {
        text.utf16.starts(with: prefix.utf16)
    }

    /// Dart `text.contains(other)`: a code-unit substring search.
    public static func contains(_ text: String, _ other: String) -> Bool {
        let haystack = Array(text.utf16), needle = Array(other.utf16)
        if needle.isEmpty { return true }
        if needle.count > haystack.count { return false }
        for start in 0...(haystack.count - needle.count) where haystack[start] == needle[0] {
            if haystack[start..<(start + needle.count)].elementsEqual(needle) { return true }
        }
        return false
    }

    /// Dart `a.compareTo(b) < 0`: code-unit order.
    public static func precedes(_ a: String, _ b: String) -> Bool {
        a.utf16.lexicographicallyPrecedes(b.utf16)
    }
}
