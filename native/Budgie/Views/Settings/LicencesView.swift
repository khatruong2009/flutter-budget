import SwiftUI

/// Settings > About > Licences: the SIL OFL texts the bundled fonts require
/// to travel with them.
struct LicencesView: View {
    private let licences: [(title: String, file: String)] = [
        ("Gabarito", "OFL-Gabarito"),
        ("Spline Sans Mono", "OFL-SplineSansMono"),
    ]

    var body: some View {
        List {
            ForEach(licences, id: \.file) { licence in
                Section(licence.title) {
                    Text(Self.text(licence.file))
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Licences")
    }

    static func text(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return "" }
        return text
    }
}
