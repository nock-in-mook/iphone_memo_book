import SwiftUI
import SwiftData

@main
struct SokuMemoKunApp: App {
    let sharedContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: Memo.self, Tag.self)
        self.sharedContainer = container
        Self.setupDefaultTags(container: container)
        // ダミーメモ投入は無効化（テスト完了）
        // Self.insertDummyMemos(container: container)
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
            let shigoto = Tag(name: "仕事", colorIndex: 1)
            let shumi = Tag(name: "趣味", colorIndex: 2)
            let kaimono = Tag(name: "買い物", colorIndex: 3)
            let idea = Tag(name: "アイデア", colorIndex: 4)
            context.insert(shigoto)
            context.insert(shumi)
            context.insert(kaimono)
            context.insert(idea)

            // 子タグ（仕事の下）
            let childTags1: [(String, Int)] = [("会議", 8), ("タスク", 9), ("経費", 15)]
            for (name, color) in childTags1 {
                context.insert(Tag(name: name, colorIndex: color, parentTagID: shigoto.id))
            }
            // 子タグ（趣味の下）
            let childTags2: [(String, Int)] = [("ギター", 22), ("ランニング", 23), ("映画", 24)]
            for (name, color) in childTags2 {
                context.insert(Tag(name: name, colorIndex: color, parentTagID: shumi.id))
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
        let key = "dummyMemosV2"
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
            "アイデア": {
                // 100件のアイデアメモを生成
                let ideas: [(String, String)] = [
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
                    ("AR", "AR家具配置シミュレーター"),
                    ("音楽", "AIが作曲してくれるアプリ"),
                    ("翻訳", "リアルタイム翻訳メガネ"),
                    ("農業", "ドローンで畑を自動管理"),
                    ("ペット", "犬の感情分析カメラ"),
                    ("旅行", "AIが旅程を組んでくれるアプリ"),
                    ("読書", "本の要約を3分で読めるサービス"),
                    ("防災", "地域密着型の災害情報共有アプリ"),
                ]
                var result: [(String, String)] = []
                for i in 0..<100 {
                    let base = ideas[i % ideas.count]
                    let title = i < ideas.count ? base.0 : "\(base.0) #\(i + 1)"
                    result.append((title, base.1))
                }
                return result
            }(),
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

        // マークダウンメモ（タグなし）
        let mdMemos: [(String, String)] = [
            ("会議メモMD", "# 定例会議\n\n## 議題\n- 売上報告\n- 新規プロジェクト\n- **来週までの宿題**\n\n> 次回は金曜15時"),
            ("レシピMD", "# カルボナーラ\n\n## 材料\n- パスタ 200g\n- ベーコン 100g\n- 卵 2個\n- **パルメザンチーズ** たっぷり\n\n## 手順\n1. パスタを茹でる\n2. ベーコンを炒める\n3. 卵とチーズを混ぜる"),
            ("勉強ノートMD", "# Swift入門\n\n## 変数\n- `let` は定数\n- `var` は変数\n\n## 関数\n- `func 名前() -> 型`\n\n> SwiftUIは**宣言的UI**フレームワーク"),
        ]
        for (title, content) in mdMemos {
            let memo = Memo(content: content, isMarkdown: true)
            memo.title = title
            context.insert(memo)
        }

        // マークダウンメモ（アイデアタグ付き）
        if let ideaTag = tags.first(where: { $0.name == "アイデア" }) {
            let mdIdeas: [(String, String)] = [
                ("企画書MD", "# 新アプリ企画\n\n## コンセプト\n**最速メモ体験**\n\n## ターゲット\n- ビジネスマン\n- 学生\n\n## 差別化\n> 起動0.5秒で入力開始"),
                ("技術調査MD", "# SwiftData vs CoreData\n\n## SwiftData\n- iOS 17+\n- **コード量が少ない**\n- CloudKit統合済み\n\n## CoreData\n- 枯れた技術\n- 複雑だが柔軟"),
            ]
            for (title, content) in mdIdeas {
                let memo = Memo(content: content, isMarkdown: true)
                memo.title = title
                memo.tags.append(ideaTag)
                context.insert(memo)
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
