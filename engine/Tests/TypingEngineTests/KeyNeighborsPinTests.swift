import Testing
import Foundation
@testable import TypingEngine

/// The slip generator (eval/slips/gen_slips.py) rebuilds key adjacency from
/// the same stock geometry KeyNeighbors uses. The two must agree on every
/// pair, or the slips it types are not the slips the engine reasons about.
@Suite struct KeyNeighborsPinTests {
    @Test func theGeneratorsAdjacencyIsTheEngines() throws {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("eval/slips/adjacency.tsv")
        let lines = try String(contentsOf: path, encoding: .utf8)
            .split(separator: "\n").dropFirst()
        #expect(lines.count == 26)
        for line in lines {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            let letter = cols[0].first!
            let listed = Set(cols.count > 1 ? cols[1] : "")
            for other in "abcdefghijklmnopqrstuvwxyz" where other != letter {
                #expect(KeyNeighbors.areAdjacent(letter, other) == listed.contains(other),
                        "\(letter)-\(other)")
            }
        }
    }
}
