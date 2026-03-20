import Foundation
import SwiftData

// 単語×タグの出現頻度（ユーザー学習データ）
@Model
final class TagFrequency {
    var id: UUID = UUID()
    var word: String = ""          // マッチした単語（正規化済み）
    var tagID: UUID = UUID()       // 紐づくタグのID
    var count: Int = 0             // 出現回数
    var hour: Int = -1             // 保存時の時間帯（0-23、-1=未記録）
    var weekday: Int = -1          // 保存時の曜日（1=日〜7=土、-1=未記録）
    var lastUsedAt: Date = Date()  // 最終使用日時

    init(word: String, tagID: UUID, hour: Int = -1, weekday: Int = -1) {
        self.id = UUID()
        self.word = word
        self.tagID = tagID
        self.count = 1
        self.hour = hour
        self.weekday = weekday
        self.lastUsedAt = Date()
    }
}
