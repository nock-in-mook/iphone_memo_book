import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorIndex: Int = 1
    var gridSize: Int = 2  // 0=小(2×4), 1=中(3×6), 2=大(4×8)
    var memos: [Memo] = []
    var todoItems: [TodoItem] = []  // ToDoとの多対多リレーション
    var parentTagID: UUID?  // nil = トップレベルタグ（親タグ）
    var sortOrder: Int = 0  // タブの並び順（小さいほど左）

    init(name: String, colorIndex: Int = 1, parentTagID: UUID? = nil) {
        self.id = UUID()
        self.name = name
        self.colorIndex = colorIndex
        self.parentTagID = parentTagID
    }
}
