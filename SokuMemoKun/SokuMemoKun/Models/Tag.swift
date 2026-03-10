import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 1
    var gridSize: Int = 2  // 0=小(2×4), 1=中(3×6), 2=大(4×8)
    var memos: [Memo] = []

    init(name: String, colorIndex: Int = 1) {
        self.id = UUID()
        self.name = name
        self.colorIndex = colorIndex
    }
}
