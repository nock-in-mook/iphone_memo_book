import SwiftUI
import SwiftData

@main
struct SokuMemoKunApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    createDefaultTagsIfNeeded()
                }
        }
        .modelContainer(for: [Memo.self, Tag.self])
    }

    // 初回起動時にデフォルトタグを作成
    private func createDefaultTagsIfNeeded() {
        guard let container = try? ModelContainer(for: Memo.self, Tag.self) else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Tag>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let defaults: [(String, Int)] = [("仕事", 1), ("趣味", 2), ("買い物", 3), ("アイデア", 4)]
            for (name, color) in defaults {
                context.insert(Tag(name: name, colorIndex: color))
            }
            try? context.save()
        }
    }
}
