import Foundation
import SwiftData

// タグ使用履歴（親+子の組み合わせを記録）
@Model
final class TagHistory {
    var parentTagID: UUID
    var childTagID: UUID?  // 子タグなしの場合はnil
    var usedAt: Date

    init(parentTagID: UUID, childTagID: UUID? = nil, usedAt: Date = .now) {
        self.parentTagID = parentTagID
        self.childTagID = childTagID
        self.usedAt = usedAt
    }

    // 履歴を記録（重複は最新に更新、最大20件）
    static func record(parentTagID: UUID, childTagID: UUID?, context: ModelContext) {
        // 同じ組み合わせがあれば日時更新
        let allHistory = (try? context.fetch(FetchDescriptor<TagHistory>())) ?? []
        if let existing = allHistory.first(where: { $0.parentTagID == parentTagID && $0.childTagID == childTagID }) {
            existing.usedAt = .now
        } else {
            context.insert(TagHistory(parentTagID: parentTagID, childTagID: childTagID))
        }
        // 20件を超えたら古い順に削除
        let sorted = allHistory.sorted { $0.usedAt > $1.usedAt }
        if sorted.count > 20 {
            for old in sorted.dropFirst(20) {
                context.delete(old)
            }
        }
        try? context.save()
    }

    // 履歴を取得（新しい順）
    static func recentHistory(context: ModelContext) -> [TagHistory] {
        let descriptor = FetchDescriptor<TagHistory>(sortBy: [SortDescriptor(\.usedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
