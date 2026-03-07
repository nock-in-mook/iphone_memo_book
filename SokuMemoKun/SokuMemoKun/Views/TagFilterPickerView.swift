import SwiftUI
import SwiftData

struct TagFilterPickerView: View {
    @Binding var selectedTag: Tag?
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTagID: String = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 「すべて」ボタン
                tagButton(label: "すべて", id: "")

                // 既存タグ
                ForEach(tags) { tag in
                    tagButton(label: tag.name, id: tag.id.uuidString)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func tagButton(label: String, id: String) -> some View {
        let isSelected = selectedTagID == id
        return Button {
            selectedTagID = id
            if id.isEmpty {
                selectedTag = nil
            } else {
                selectedTag = tags.first { $0.id.uuidString == id }
            }
        } label: {
            Text(label)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
