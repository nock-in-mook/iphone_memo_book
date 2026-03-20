import Foundation
import SwiftData

// サジェスト却下の記録（否定学習）
@Model
final class TagSuggestDismissal {
    var id: UUID = UUID()
    var word: String = ""      // 入力中だった単語
    var tagID: UUID = UUID()   // 却下されたタグのID
    var count: Int = 0         // 却下回数
    var lastDismissedAt: Date = Date()

    init(word: String, tagID: UUID) {
        self.id = UUID()
        self.word = word
        self.tagID = tagID
        self.count = 1
        self.lastDismissedAt = Date()
    }
}
