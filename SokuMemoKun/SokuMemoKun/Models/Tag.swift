import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 1
    var memos: [Memo] = []

    init(name: String, colorIndex: Int = 1) {
        self.id = UUID()
        self.name = name
        self.colorIndex = colorIndex
    }
}
