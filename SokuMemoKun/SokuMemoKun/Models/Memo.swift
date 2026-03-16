import Foundation
import SwiftData

@Model
final class Memo {
    var id: UUID = UUID()
    var content: String = ""
    var title: String = ""
    @Relationship(inverse: \Tag.memos) var tags: [Tag] = []
    var isMarkdown: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var isPinned: Bool = false
    var manualSortOrder: Int = 0

    init(content: String, title: String = "", tags: [Tag] = [], isMarkdown: Bool = false) {
        self.id = UUID()
        self.content = content
        self.title = title
        self.tags = tags
        self.isMarkdown = isMarkdown
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.manualSortOrder = 0
    }
}
