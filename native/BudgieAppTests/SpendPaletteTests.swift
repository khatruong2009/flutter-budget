import BudgieCore
import SwiftUI
import UIKit
import XCTest

@testable import Runner

/// The Spend palette slots resolve to the colours the Flutter page paints
/// (app_colors.dart: rank palette, light `categoryColors` :200-215, dark
/// chart list :223-238, `getDonutRemainder`). The tables are the ones in
/// BudgieCoreTests/SpendParityTests.swift.
final class SpendPaletteTests: XCTestCase {
    private let rank = (
        light: ["6366f1", "10b981", "ef4444", "f59e0b", "3b82f6", "f0abfc"],
        dark: ["818cf8", "34d399", "fb7185", "fbbf24", "60a5fa", "f0abfc"])
    private let chart = (
        light: ["6366f1", "8b5cf6", "10b981", "34d399", "ef4444", "f87171", "f59e0b", "fbbf24", "3b82f6", "60a5fa", "ec4899",
                "f472b6", "14b8a6", "2dd4bf"],
        dark: ["818cf8", "a78bfa", "34d399", "6ee7b7", "f87171", "fca5a5", "fbbf24", "fcd34d", "60a5fa", "93c5fd", "f472b6",
               "f9a8d4", "2dd4bf", "5eead4"])

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
        XCTAssertEqual(hex(.remainder, dark: false), "c9c9da")
        XCTAssertEqual(hex(.remainder, dark: true), "3a3a52")
    }
}
