import Testing

@testable import BudgieCore

/// Behaviours of csv 6.0.0 with the app's settings, each checked in Dart
/// (the random differential is in CSVImportParityTests).
@Suite("CSVParser: csv 6.0.0 CsvToListConverter as the app calls it")
struct CSVParserTests {
    static let behaviours: [(String, [[String]])] = [
            ("a,b\r\nc,d", [["a", "b"], ["c", "d"]]),
            ("a,b\r\nc,d\r\n", [["a", "b"], ["c", "d"]]),
            ("a,b\nc,d\n", [["a", "b"], ["c", "d"]]),
            ("", []),
            ("\n", [[""]]),
            ("a,b\r\n\r\nc", [["a", "b"], [""], ["c"]]),
            ("\r\n\r\na", [[""], [""], ["a"]]),
            ("a,b,", [["a", "b", ""]]),
            ("a,b\r", [["a", "b\r"]]),
            ("a\r\r\nb", [["a\r"], ["b"]]),
            ("a\rb\rc", [["a\rb\rc"]]),
            ("\"", []),
            ("a\n\"", [["a"]]),
            ("a\n\"\"", [["a"], [""]]),
            ("a\n\"x", [["a"], ["x"]]),
            ("\"a\"\"b\",c", [["a\"b", "c"]]),
            ("a\"b\"c,d", [["a\"b\"c", "d"]]),
            (" \"abc\",d", [[" \"abc\"", "d"]]),
            ("\"abc\"def,ghi\nx,y", [["abcdef,ghi\nx,y"]]),
            ("\"a\"\rb,c\r\n1,2", [["a\rb,c\r\n1,2"]]),
            ("a,b\r\nc,d\ne,f", [["a", "b"], ["c", "d\ne", "f"]]),
            ("a,b\nc,d\r\ne,f", [["a", "b"], ["c", "d\r"], ["e", "f"]]),
            ("a,\"b\nb\"\r\nc", [["a", "b\nb\r\nc"]]),
            ("\u{FEFF}a,b", [["\u{FEFF}a", "b"]]),
            ("\"\",\"\"", [["", ""]]),
            ("007,1e3", [["007", "1e3"]]),
    ]

    @Test("documented behaviours")
    func behaviour() {
        for (input, expected) in Self.behaviours {
            let rows = CSVParser.parse(input)
            // Compare as code units: "\r\n" is one Character in Swift.
            #expect(rows.map { $0.map { Array($0.utf16) } } == expected.map { $0.map { Array($0.utf16) } }, "\(Array(input.utf16))")
        }
    }

    @Test("rows of any length come back; nothing throws on an unterminated quote")
    func ragged() {
        let rows = CSVParser.parse("a\nb,c,d\n\"open,e\nf")
        #expect(rows == [["a"], ["b", "c", "d"], ["open,e\nf"]])
    }
}
