import Foundation
import SwiftData

// タグの共起関係（同一メモで併用されたタグペア）
@Model
final class TagCooccurrence {
    var id: UUID = UUID()
    var tagID1: UUID = UUID()  // タグペアの片方（小さいUUID）
    var tagID2: UUID = UUID()  // タグペアのもう片方（大きいUUID）
    var count: Int = 0         // 共起回数
    var lastUsedAt: Date = Date()

    init(tagID1: UUID, tagID2: UUID) {
        self.id = UUID()
        // 順序を正規化（常に小さい方をtagID1に）
        if tagID1.uuidString < tagID2.uuidString {
            self.tagID1 = tagID1
            self.tagID2 = tagID2
        } else {
            self.tagID1 = tagID2
            self.tagID2 = tagID1
        }
        self.count = 1
        self.lastUsedAt = Date()
    }
}
