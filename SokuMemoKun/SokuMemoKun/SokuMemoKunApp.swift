import SwiftUI
import SwiftData

@main
struct SokuMemoKunApp: App {
    let sharedContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: Memo.self, Tag.self)
        self.sharedContainer = container
        Self.setupDefaultTags(container: container)
        Self.insertDummyMemos(container: container)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedContainer)
    }

    // 初回起動時にデフォルトタグを作成 + 既存タグの色修正
    private static func setupDefaultTags(container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        let existingTags = (try? context.fetch(descriptor)) ?? []

        if existingTags.isEmpty {
            // 新規: デフォルトタグ作成
            let defaults: [(String, Int)] = [("仕事", 1), ("趣味", 2), ("買い物", 3), ("アイデア", 4)]
            for (name, color) in defaults {
                context.insert(Tag(name: name, colorIndex: color))
            }
        } else {
            // 既存タグの色が未設定（全部同じ）なら順番に振り直す
            let needsFix = existingTags.count > 1 && Set(existingTags.map { $0.colorIndex }).count <= 1
            if needsFix {
                for (i, tag) in existingTags.enumerated() {
                    tag.colorIndex = (i % 7) + 1
                }
            }
        }
        try? context.save()
    }

    // ダミーメモ投入（一度だけ実行）
    private static func insertDummyMemos(container: ModelContainer) {
        let key = "dummyMemosInserted"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let context = ModelContext(container)
        let tags = (try? context.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)]))) ?? []

        // タグなしメモ（多め: 15枚）
        let noTagMemos = [
            ("買い物リスト", "牛乳、卵、パン、バター"),
            ("パスワードメモ", "WiFi: hogehoge-5G"),
            ("映画リスト", "観たい映画: インターステラー、テネット"),
            ("読書メモ", "「嫌われる勇気」第3章まで読了"),
            ("ラーメン屋", "駅前の新しいラーメン屋が美味しいらしい"),
            ("電話番号", "歯医者: 03-1234-5678"),
            ("引っ越し", "来月の引っ越し準備チェックリスト"),
            ("レシピ", "カレー: 玉ねぎ3個、にんじん2本、じゃがいも4個"),
            ("名言", "明日やろうは馬鹿野郎"),
            ("プレゼント", "母の日に花を贈る"),
            ("旅行", "夏休みに沖縄行きたい"),
            ("メモ", "銀行の振込は月末まで"),
            ("体重記録", "68.5kg → 目標65kg"),
            ("音楽", "新しいプレイリスト作る"),
            ("TODO", "クリーニング取りに行く"),
        ]
        for (title, content) in noTagMemos {
            let memo = Memo(content: content)
            memo.title = title
            context.insert(memo)
        }

        // 各タグに割り当て
        // タグ名→枚数: アイデア=多め(12), 仕事=普通(8), 買い物=少なめ(4), 趣味=普通(6)
        let tagData: [String: [(String, String)]] = [
            "アイデア": [
                ("アプリ案", "家計簿×AIアシスタント"),
                ("新サービス", "ペット見守りカメラのサブスク"),
                ("ブログネタ", "SwiftUIの便利Tips 10選"),
                ("副業", "プログラミング教室をオンラインで"),
                ("デザイン", "ミニマリスト風のポートフォリオ"),
                ("IoT", "スマート植木鉢で水やり自動化"),
                ("ゲーム", "パズル×RPGのハイブリッドゲーム"),
                ("SNS", "匿名質問箱アプリ"),
                ("教育", "子供向けプログラミング学習ゲーム"),
                ("音声AI", "会議の議事録を自動生成"),
                ("健康", "睡眠トラッキング＋アドバイスアプリ"),
                ("料理", "冷蔵庫の中身からレシピ提案AI"),
            ],
            "仕事": [
                ("会議メモ", "来週月曜14時 定例ミーティング"),
                ("タスク", "企画書を金曜までに提出"),
                ("議事録", "Q3売上目標: 前年比120%"),
                ("連絡先", "田中さん: tanaka@example.com"),
                ("出張", "大阪出張 3/25-26 新幹線予約済み"),
                ("経費", "交通費精算 3月分まとめる"),
                ("プレゼン", "新商品プレゼン資料のドラフト"),
                ("面談", "来月の1on1で目標設定の話"),
            ],
            "買い物": [
                ("食料品", "醤油、味噌、豆腐、納豆"),
                ("日用品", "ティッシュ、洗剤、ゴミ袋"),
                ("家電", "新しい加湿器を探す"),
                ("服", "夏用のTシャツ3枚くらい"),
            ],
            "趣味": [
                ("ギター", "Fコード練習中。押さえ方のコツ"),
                ("ランニング", "今月の目標: 月間50km"),
                ("写真", "桜が咲いたら撮影に行く"),
                ("キャンプ", "テント新調したい。MSR?スノーピーク?"),
                ("映画", "週末にネットフリックス新作チェック"),
                ("料理", "パスタのカルボナーラに挑戦"),
            ],
        ]

        for tag in tags {
            if let memos = tagData[tag.name] {
                for (title, content) in memos {
                    let memo = Memo(content: content)
                    memo.title = title
                    memo.tags.append(tag)
                    context.insert(memo)
                }
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
