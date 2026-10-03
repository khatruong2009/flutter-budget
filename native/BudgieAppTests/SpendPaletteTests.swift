import BudgieCore
import SwiftUI
import UIKit
import XCTest

@testable import Runner

/// The Spend palette slots resolve to the redesign's colours (owner-approved
/// 2026-10-03, PARITY_GAPS "Visual redesign"): the rank palette, the
/// 14-colour chart palette and the donut remainder, light and dark. The slot
/// order is still Flutter's (BudgieCoreTests/SpendParityTests.swift).
final class SpendPaletteTests: XCTestCase {
    private let rank = (
        light: ["5b47b8", "1d6646", "a63d24", "7e5300", "1f5f99", "7f3b6b"],
        dark: ["b3adff", "5ee6b0", "ff8b7b", "ffc861", "7cc8ff", "f7a1d8"])
    private let chart = (
        light: ["1d6646", "5b47b8", "a63d24", "7e5300", "1f5f99", "7f3b6b", "176464", "4e8f6f", "8676d1", "c96a50", "a8801f",
                "4e86bd", "a86394", "3f8c8c"],
        dark: ["5ee6b0", "b3adff", "ff8b7b", "ffc861", "7cc8ff", "f7a1d8", "4fd1c5", "a3f0d2", "d6d2ff", "ffb8ad", "ffde9c",
               "b4dfff", "fac8e8", "93e4db"])

    @MainActor
    private func hex(_ slot: SpendPaletteSlot, dark: Bool) -> String {
        let color = UIColor(slot.color).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual(alpha, 1, "\(slot) is opaque")
        return [red, green, blue].map { String(format: "%02x", Int(($0 * 255).rounded())) }.joined()
    }

    @MainActor
    func testRankPalette() {
        XCTAssertEqual(CategoryBreakdown.rankPalette.count, 6)
        for (index, slot) in CategoryBreakdown.rankPalette.enumerated() {
            XCTAssertEqual(hex(slot, dark: false), rank.light[index], "light rank \(index)")
            XCTAssertEqual(hex(slot, dark: true), rank.dark[index], "dark rank \(index)")
        }
    }

    @MainActor
    func testChartColours() {
        XCTAssertEqual(CategoryBreakdown.chartColorCount, chart.light.count)
        for index in 0..<CategoryBreakdown.chartColorCount {
            XCTAssertEqual(hex(.chart(index), dark: false), chart.light[index], "light chart \(index)")
            XCTAssertEqual(hex(.chart(index), dark: true), chart.dark[index], "dark chart \(index)")
        }
    }

    @MainActor
    func testRemainder() {
        XCTAssertEqual(hex(.remainder, dark: false), "cfc6b4")
        XCTAssertEqual(hex(.remainder, dark: true), "2a3140")
    }
}
