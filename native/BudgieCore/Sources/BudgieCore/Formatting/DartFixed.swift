/// Dart's `double.toStringAsFixed(digits)`.
///
/// Dart rounds the exact binary value of the double (not its shortest decimal
/// representation), and exact ties (values such as 0.125 that are exactly half
/// way) round away from zero. `String(format: "%.2f")` rounds exact ties to
/// even, so it cannot be used. This port expands the double into its exact
/// decimal digits with arbitrary-precision arithmetic and rounds those.
///
/// Semantics matched, verified against Fixtures/logic/numbers.json:
/// - the sign is kept for every negative value, including results that round
///   to zero (`-0.001` -> `-0.00`) and negative zero (`-0.0` -> `-0.00`);
/// - values with `abs >= 1e21` print like `toString()` (exponent form);
/// - NaN and infinities print as `NaN`, `Infinity`, `-Infinity`.
public enum DartFixed {
    public static func toStringAsFixed(_ value: Double, _ digits: Int) -> String {
        precondition((0...20).contains(digits), "Dart allows 0...20 fraction digits")
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        if value.magnitude >= 1e21 { return DartDouble.format(value) }

        // magnitude = mantissa * 2^exponent exactly.
        let mantissa: UInt64
        let exponent: Int
        let biased = Int(value.bitPattern >> 52) & 0x7FF
        let fraction = value.bitPattern & 0x000F_FFFF_FFFF_FFFF
        if biased == 0 {
            mantissa = fraction
            exponent = -1074
        } else {
            mantissa = fraction | (1 << 52)
            exponent = biased - 1075
        }

        // Exact decimal digits of the magnitude, `scale` of them after the
        // decimal point: m * 2^e = m * 5^k / 10^k when e = -k < 0.
        var limbs = BigDecimalLimbs(mantissa)
        var scale = 0
        if exponent >= 0 {
            limbs.multiply(byPowerOf: 2, exponent: exponent)
        } else {
            scale = -exponent
            limbs.multiply(byPowerOf: 5, exponent: scale)
        }
        var all = limbs.decimalDigits()
        if all.count < scale + 1 {
            all.insert(contentsOf: [UInt8](repeating: 0, count: scale + 1 - all.count), at: 0)
        }

        var kept: [UInt8]  // integer digits followed by exactly `digits` fraction digits
        let integerCount = all.count - scale
        if scale <= digits {
            kept = all + [UInt8](repeating: 0, count: digits - scale)
        } else {
            kept = Array(all[0..<(integerCount + digits)])
            // Exact value: the first dropped digit >= 5 means at least half way,
            // and half way rounds away from zero, so this is round-half-up on
            // the magnitude.
            if all[integerCount + digits] >= 5 {
                var index = kept.count - 1
                while index >= 0 {
                    if kept[index] == 9 {
                        kept[index] = 0
                        index -= 1
                    } else {
                        kept[index] += 1
                        break
                    }
                }
                if index < 0 { kept.insert(1, at: 0) }
            }
        }

        var integerDigits = Array(kept[0..<(kept.count - digits)])
        while integerDigits.count > 1 && integerDigits[0] == 0 { integerDigits.removeFirst() }
        var text = value.sign == .minus ? "-" : ""
        text.unicodeScalars.append(contentsOf: integerDigits.map { Unicode.Scalar($0 + 48) })
        if digits > 0 {
            text += "."
            text.unicodeScalars.append(
                contentsOf: kept[(kept.count - digits)...].map { Unicode.Scalar($0 + 48) })
        }
        return text
    }
}

/// Minimal unsigned big integer in base 10^9 (little endian limbs).
private struct BigDecimalLimbs {
    private static let base: UInt64 = 1_000_000_000
    private var limbs: [UInt32]

    init(_ value: UInt64) {
        limbs = []
        var rest = value
        repeat {
            limbs.append(UInt32(rest % BigDecimalLimbs.base))
            rest /= BigDecimalLimbs.base
        } while rest > 0
    }

    mutating func multiply(byPowerOf factor: UInt64, exponent: Int) {
        // Largest power of `factor` below 2^31 keeps limb * chunk + carry inside UInt64.
        var chunk: UInt64 = 1
        var chunkExponent = 0
        while chunk * factor < (1 << 31) {
            chunk *= factor
            chunkExponent += 1
        }
        var remaining = exponent
        while remaining >= chunkExponent {
            multiply(bySmall: chunk)
            remaining -= chunkExponent
        }
        var tail: UInt64 = 1
        for _ in 0..<remaining { tail *= factor }
        if tail > 1 { multiply(bySmall: tail) }
    }

    private mutating func multiply(bySmall factor: UInt64) {
        var carry: UInt64 = 0
        for index in limbs.indices {
            let product = UInt64(limbs[index]) * factor + carry
            limbs[index] = UInt32(product % BigDecimalLimbs.base)
            carry = product / BigDecimalLimbs.base
        }
        while carry > 0 {
            limbs.append(UInt32(carry % BigDecimalLimbs.base))
            carry /= BigDecimalLimbs.base
        }
    }

    /// Decimal digits (0...9), most significant first, without leading zeros
    /// (a single 0 for zero).
    func decimalDigits() -> [UInt8] {
        var result: [UInt8] = []
        for (position, limb) in limbs.reversed().enumerated() {
            var chunk = [UInt8](repeating: 0, count: 9)
            var rest = limb
            for index in stride(from: 8, through: 0, by: -1) {
                chunk[index] = UInt8(rest % 10)
                rest /= 10
            }
            if position == 0 {
                let firstNonZero = chunk.firstIndex(where: { $0 != 0 }) ?? 8
                result.append(contentsOf: chunk[firstNonZero...])
            } else {
                result.append(contentsOf: chunk)
            }
        }
        return result
    }
}
