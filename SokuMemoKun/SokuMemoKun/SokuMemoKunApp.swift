import SwiftUI
import SwiftData

@main
struct SokuMemoKunApp: App {
    let sharedContainer: ModelContainer

    init() {
        let container = try! ModelContainer(for: Memo.self, Tag.self)
        self.sharedContainer = container
        // データリセット＆サンプル投入（一度だけ実行）
        Self.resetAndInsertSamples(container: container)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .modelContainer(sharedContainer)
    }

    // MARK: - テストデータ生成

    // 全データ削除→バリエーション豊富なサンプル投入
    private static func resetAndInsertSamples(container: ModelContainer) {
        let key = "sampleDataV8"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let context = ModelContext(container)

        // 既存データ全削除
        let allMemos = (try? context.fetch(FetchDescriptor<Memo>())) ?? []
        for memo in allMemos { context.delete(memo) }
        let allTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        for tag in allTags { context.delete(tag) }
        try? context.save()

        // タグ構造を作成
        let tags = createTags(context: context)
        // メモを生成
        generateVariedMemos(context: context, tags: tags)

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }

    // ── タグ構造 ──
    private struct TagSet {
        let parents: [Tag]        // 親タグ一覧
        let children: [UUID: [Tag]] // 親タグID → 子タグ配列
    }

    private static func createTags(context: ModelContext) -> TagSet {
        // 親タグ
        let shigoto = Tag(name: "仕事", colorIndex: 1)
        let idea = Tag(name: "アイデア", colorIndex: 4)
        let kaimono = Tag(name: "買い物", colorIndex: 3)
        let shumi = Tag(name: "趣味", colorIndex: 2)
        let kenkou = Tag(name: "健康", colorIndex: 5)
        let parents = [shigoto, idea, kaimono, shumi, kenkou]
        for (i, tag) in parents.enumerated() {
            tag.sortOrder = i + 1  // 1始まり（0はタグなし用に空けておく）
            context.insert(tag)
        }

        // 子タグ
        var children: [UUID: [Tag]] = [:]
        let childDefs: [(Tag, [(String, Int)])] = [
            (shigoto, [("会議", 8), ("タスク", 9), ("経費", 15)]),
            (shumi, [("ギター", 22), ("ランニング", 23), ("映画", 24)]),
            (idea, [("アプリ", 10), ("ビジネス", 11)]),
            (kenkou, [("食事", 16), ("運動", 17)]),
            (shigoto, [("企画", 12), ("営業", 13), ("開発", 14), ("人事", 6), ("総務", 7), ("広報", 18), ("法務", 19), ("経理", 20), ("品質", 21), ("教育", 25), ("海外", 26), ("保守", 27)]),
        ]
        for (parent, defs) in childDefs {
            var childTags: [Tag] = []
            for (name, color) in defs {
                let tag = Tag(name: name, colorIndex: color, parentTagID: parent.id)
                context.insert(tag)
                childTags.append(tag)
            }
            children[parent.id] = childTags
        }

        return TagSet(parents: parents, children: children)
    }

    // ── シンプルな疑似乱数（シード固定で再現性あり）──
    private struct SeededRNG {
        var state: UInt64
        init(seed: UInt64) { self.state = seed }

        mutating func next() -> UInt64 {
            // xorshift64
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }

        // 0..<n の範囲でランダム整数
        mutating func nextInt(_ n: Int) -> Int {
            return Int(next() % UInt64(n))
        }

        // 確率判定（0.0〜1.0）
        mutating func chance(_ probability: Double) -> Bool {
            return Double(next() % 1000) / 1000.0 < probability
        }

        // 配列からランダム選択
        mutating func pick<T>(_ array: [T]) -> T {
            return array[nextInt(array.count)]
        }
    }

    // ── メモ生成本体 ──
    private static func generateVariedMemos(context: ModelContext, tags: TagSet) {
        var rng = SeededRNG(seed: 42)

        // --- テキスト素材 ---

        // 超短文（1〜10文字）
        let tinyTexts = [
            "OK", "了解", "あとで", "要確認", "買った", "☎️", "明日",
            "パス: 1234", "済", "!!", "w", "ありがとう", "🍺", "メモ",
            "YES", "NG", "後で読む", "〇", "✕", "?",
        ]

        // 短文（1〜2行）
        let shortTexts = [
            "牛乳、卵、パン",
            "来週月曜14時 3F会議室",
            "tanaka@example.com / 内線: 3456",
            "明日やろうは馬鹿野郎",
            "WiFi: hogehoge-5G",
            "振込は月末まで",
            "口座番号: 1234567",
            "3/25 新幹線予約済み",
            "ビタミンD、マグネシウム",
            "次回 4/15 14:00 歯医者",
            "アレグラ、目薬、マスク",
            "Fコード押さえ方メモ",
            "今月50km目標",
            "23時就寝→6時起床",
            "パスタ200g、卵2個",
        ]

        // 中文（3〜5行相当）
        let mediumTexts = [
            "Q3売上目標: 前年比120%\n新規案件2件獲得\n来月のプレゼンまでに資料まとめ",
            "加湿器を比較中\nダイキン: 静音性◎、電気代△\nシャープ: プラズマクラスター付き\nパナソニック: デザイン良い\n→週末に家電量販店で実物見る",
            "朝: ヨーグルト+グラノーラ\n昼: サラダチキン+玄米\n夜: 鍋（白菜、豆腐、鶏肉）\n間食: ナッツ少々\n水分: 1.8L",
            "映画メモ\n・インターステラー ★★★★★\n・テネット ★★★★\n・DUNE ★★★★\n・オッペンハイマー まだ観てない",
            "キャンプ装備リスト\nテント: MSR Hubba Hubba\nシュラフ: モンベル #3\nマット: サーマレスト\nバーナー: SOTO ST-310\n→合計予算8万くらい",
            "新人向け研修スライド更新\n- Swift基礎（2時間）\n- SwiftUI入門（3時間）\n- Git/GitHub運用（1時間）\n- コードレビューの作法（1時間）\n4月第1週までに完成させる",
            "ランニング記録 3月\n3/1: 5km 28分（快調）\n3/5: 3km 17分（雨で短縮）\n3/8: 7km 42分（ペース維持）\n3/12: 10km 58分（自己ベスト更新！）",
            "1on1メモ\n- 来月の目標設定について\n- スキルアップ計画（AWS資格）\n- チーム内の役割分担見直し\n- 有給消化の計画",
        ]

        // 長文（10行以上）
        let longTexts = [
            """
            プロジェクト計画書 下書き

            【背景】
            現行の社内ツールが老朽化しており、業務効率が低下している。
            特に経費精算と勤怠管理のシステムは10年以上前のもので、
            スマホ対応もされていない。

            【目的】
            モバイルファーストの新システムを構築し、
            申請〜承認のフローを簡素化する。

            【スコープ】
            Phase1: 経費精算（4月〜6月）
            Phase2: 勤怠管理（7月〜9月）
            Phase3: 統合ダッシュボード（10月〜12月）

            【予算】
            開発費: 2,000万円
            インフラ: 月額30万円（AWS）
            保守: 年間500万円

            【リスク】
            - 既存データの移行に時間がかかる可能性
            - ユーザーの操作習熟に研修が必要
            - セキュリティ監査の通過
            """,
            """
            読書ノート「サピエンス全史」

            第1部 認知革命
            ・7万年前、ホモ・サピエンスの脳に何かが起きた
            ・虚構を信じる能力が大規模協力を可能にした
            ・噂話が社会的結束を強めた（150人の壁）

            第2部 農業革命
            ・「史上最大の詐欺」とハラリは呼ぶ
            ・小麦がヒトを家畜化した、という逆転の視点
            ・定住→人口増加→もう狩猟採集には戻れない

            第3部 人類の統一
            ・貨幣・帝国・宗教が統一の原動力
            ・お金は最も普遍的な「信頼のシステム」
            ・帝国は文化の融合を促進した

            第4部 科学革命
            ・「無知の発見」が科学を生んだ
            ・科学+帝国+資本主義の三位一体
            ・ヒトは神になりつつある？

            感想:
            歴史を「物語の力」で読み解く視点が斬新。
            農業革命＝人類の堕落、という見方は衝撃的だった。
            次は「ホモ・デウス」を読みたい。
            """,
            """
            旅行計画 沖縄3泊4日

            ■ Day 1（金曜）
            - 10:00 羽田→那覇（ANA）
            - 13:00 レンタカー受取（タイムズ）
            - 14:00 首里城公園
            - 17:00 ホテルチェックイン（北谷）
            - 19:00 アメリカンビレッジで夕食

            ■ Day 2（土曜）
            - 09:00 美ら海水族館
            - 12:00 名護で沖縄そば
            - 14:00 古宇利島ドライブ
            - 16:00 ハートロック
            - 19:00 恩納村でBBQ

            ■ Day 3（日曜）
            - 09:00 青の洞窟シュノーケル（予約済み）
            - 12:00 北谷でタコス
            - 14:00 やちむんの里
            - 16:00 おみやげ買い出し
            - 19:00 国際通りで最後の夜

            ■ Day 4（月曜）
            - 09:00 チェックアウト
            - 10:00 瀬長島ウミカジテラス
            - 12:00 レンタカー返却
            - 14:00 那覇→羽田

            持ち物: 水着、日焼け止め、サングラス、
            GoProバッテリー3個、充電器
            予算: 1人あたり約12万円
            """,
            """
            アプリ開発アイデア詳細

            ■ コンセプト
            「冷蔵庫の中身を撮影→AIがレシピ提案」

            ■ ターゲット
            - 一人暮らしの20〜30代
            - 自炊したいけど献立を考えるのが面倒な人
            - 食材を余らせがちな人

            ■ 主要機能
            1. カメラで冷蔵庫を撮影
            2. 画像認識で食材を自動検出
            3. 検出された食材でレシピを提案
            4. 栄養バランスのスコア表示
            5. 買い足し提案（あと○○があれば△△が作れます）
            6. レシピの保存・お気に入り

            ■ 技術スタック
            - iOS: Swift + SwiftUI
            - 画像認識: Core ML / Vision
            - バックエンド: Firebase
            - AI: OpenAI API（レシピ生成）
            - DB: Firestore

            ■ マネタイズ
            - 基本無料（1日3回まで）
            - プレミアム: 月額480円（無制限+栄養管理）
            - 将来: スーパーとの提携（食材宅配連携）

            ■ 競合分析
            - DELISH KITCHEN: レシピ動画がメイン、食材認識なし
            - クラシル: 同上
            - Yummly（海外）: 食材入力は手動

            → 「撮るだけ」の手軽さが差別化ポイント
            """,
            """
            筋トレ12週間プログラム

            ── Week 1-4（基礎期）──
            月: 胸+三頭
              ベンチプレス 60kg×10×3
              インクラインDB 14kg×12×3
              ディップス 自重×15×3
              トライセプスPD 20kg×12×3

            水: 背中+二頭
              デッドリフト 80kg×8×3
              ラットPD 50kg×10×3
              シーテッドロー 40kg×12×3
              バーベルカール 25kg×10×3

            金: 脚+肩
              スクワット 70kg×10×3
              レッグプレス 120kg×12×3
              レッグカール 35kg×12×3
              OHP 30kg×10×3
              サイドレイズ 8kg×15×3

            ── Week 5-8（増量期）──
            各種目 +5kg / +2rep を目標
            セット間休憩: 2分→90秒に短縮
            プロテイン: トレ後30分以内に30g

            ── Week 9-12（追い込み期）──
            ドロップセット導入
            スーパーセット（拮抗筋）
            週4回に増やす（肩の日を独立）

            【栄養管理】
            タンパク質: 体重×2g = 140g/日
            炭水化物: 体重×4g = 280g/日
            脂質: 体重×0.8g = 56g/日
            総カロリー: 約2,200kcal

            【サプリ】
            - ホエイプロテイン（朝・トレ後）
            - クレアチン 5g/日
            - マルチビタミン
            - フィッシュオイル
            """,
        ]

        // マークダウン素材（短〜長まで混在）
        let markdownTexts = [
            // 超短MD
            "**重要**",
            "- [ ] やること",
            "> 名言メモ",
            // 短MD
            "# 買い物\n- 牛乳\n- 卵\n- パン",
            "## TODO\n- [x] 完了\n- [ ] 未完了\n- [ ] 検討中",
            // 中MD
            "# 定例会議\n\n## 議題\n- 売上報告\n- 新規プロジェクト\n- **来週までの宿題**\n\n> 次回は金曜15時\n\n---\n\n### メモ\n要確認事項が3つ",
            "# カルボナーラ\n\n## 材料\n- パスタ 200g\n- ベーコン 100g\n- 卵 2個\n- **パルメザンチーズ** たっぷり\n\n## 手順\n1. パスタを茹でる\n2. ベーコンを炒める\n3. 卵とチーズを混ぜる\n4. 火を止めてから和える\n\n> ⚠️ 火を通しすぎるとスクランブルエッグになる",
            // 長MD
            """
            # Swift入門ノート

            ## 基本構文

            ### 変数と定数
            - `let` は定数（変更不可）
            - `var` は変数（変更可能）

            ```swift
            let name = "太郎"
            var age = 25
            age += 1 // OK
            ```

            ### 関数
            ```swift
            func greet(name: String) -> String {
                return "Hello, \\(name)!"
            }
            ```

            ## SwiftUI

            > SwiftUIは**宣言的UI**フレームワーク

            ### 基本的なView
            | View | 用途 |
            |------|------|
            | Text | テキスト表示 |
            | Image | 画像表示 |
            | Button | ボタン |
            | List | リスト |

            ### レイアウト
            1. `VStack` - 縦並び
            2. `HStack` - 横並び
            3. `ZStack` - 重ね合わせ

            ---

            **次のステップ**: SwiftDataでデータ永続化を学ぶ
            """,
            """
            # 週次レポート 2026/03/10

            ## 今週の成果
            - [x] API設計レビュー完了
            - [x] DB移行スクリプト作成
            - [ ] フロントエンド結合テスト（80%）
            - [ ] ドキュメント更新

            ## KPI
            | 指標 | 目標 | 実績 |
            |------|------|------|
            | バグ修正 | 5件 | **7件** ✅ |
            | PR レビュー | 10件 | 8件 |
            | テストカバレッジ | 80% | 76% |

            ## 課題・リスク
            1. **認証周りの負荷テスト**が未実施
               - → 来週水曜にスケジュール済み
            2. iOS 17.4でのレイアウト崩れ
               - → 再現手順を確認中

            ## 来週の予定
            - 月: スプリントプランニング
            - 火-木: 結合テスト追い込み
            - 金: リリース判定会議

            > **一言**: 全体的に順調。テストカバレッジだけ要注意。
            """,
        ]

        // タイトル候補（ランダムに付けたり付けなかったりする）
        let titles = [
            "定例会議", "企画書", "議事録", "連絡先メモ", "出張メモ",
            "交通費", "プレゼン", "1on1", "MTGメモ", "研修",
            "予算", "日報", "面接", "ランチ", "体重記録",
            "筋トレ", "食事記録", "サプリ", "睡眠", "ストレッチ",
            "歯医者", "眼科", "花粉症", "健診", "瞑想",
            "買い物", "日用品", "家電", "ギター", "ランニング",
            "写真", "キャンプ", "映画", "レシピ", "読書",
            "旅行", "アプリ案", "ブログ", "副業", "デザイン",
            "IoT", "ゲーム", "SNS", "教育", "AI",
            "", "", "", "", "",  // タイトルなし枠（空文字）
        ]

        // ── 120枚のメモを生成 ──
        for i in 0..<120 {
            let memo: Memo

            // テキスト長さの分布を決定
            let lengthRoll = rng.nextInt(100)
            let content: String
            let isMarkdown: Bool

            // 約15%の確率でマークダウン
            if rng.chance(0.15) {
                content = rng.pick(markdownTexts)
                isMarkdown = true
            } else if lengthRoll < 15 {
                // 15%: 超短文
                content = rng.pick(tinyTexts)
                isMarkdown = false
            } else if lengthRoll < 45 {
                // 30%: 短文
                content = rng.pick(shortTexts)
                isMarkdown = false
            } else if lengthRoll < 75 {
                // 30%: 中文
                content = rng.pick(mediumTexts)
                isMarkdown = false
            } else {
                // 25%: 長文
                content = rng.pick(longTexts)
                isMarkdown = false
            }

            memo = Memo(content: content, isMarkdown: isMarkdown)

            // タイトル: 60%の確率で付ける
            if rng.chance(0.6) {
                memo.title = rng.pick(titles)
            }
            // タイトルが空文字の場合もそのまま（タイトルなし扱い）

            // タグ割り当て
            let tagRoll = rng.nextInt(100)
            if tagRoll < 25 {
                // 25%: タグなし
            } else if tagRoll < 60 {
                // 35%: 親タグのみ
                let parent = rng.pick(tags.parents)
                memo.tags.append(parent)
            } else if tagRoll < 85 {
                // 25%: 親タグ＋子タグ
                let parent = rng.pick(tags.parents)
                memo.tags.append(parent)
                if let childList = tags.children[parent.id], !childList.isEmpty {
                    memo.tags.append(rng.pick(childList))
                }
            } else {
                // 15%: 子タグのみ
                let parentsWithChildren = tags.parents.filter { tags.children[$0.id] != nil }
                if !parentsWithChildren.isEmpty {
                    let parent = rng.pick(parentsWithChildren)
                    if let childList = tags.children[parent.id], !childList.isEmpty {
                        memo.tags.append(rng.pick(childList))
                    }
                }
            }

            // 作成日時をバラけさせる（過去90日以内でランダム）
            let daysAgo = Double(rng.nextInt(90))
            let hoursAgo = Double(rng.nextInt(24))
            memo.createdAt = Date().addingTimeInterval(-(daysAgo * 86400 + hoursAgo * 3600))
            memo.updatedAt = memo.createdAt

            context.insert(memo)
        }

        // ── 検索テスト用「Claude」メモ（各タグにランダム個数）──
        let claudeTexts = [
            "Claudeに聞いてみた: SwiftUIのベストプラクティス",
            "Claude曰く「シンプルが正義」",
            "Claudeとペアプロした結果がこれ",
            "Claudeメモ: エラーハンドリングのコツ",
            "Claudeに設計レビューしてもらった",
            "Claude先生の教え: テストを書け",
            "Claudeと一緒にデバッグした夜",
            "Claude推薦図書リスト",
            "Claudeのアドバイス: まず動くものを作れ",
            "Claude「過剰な抽象化はやめとけ」",
            "Claudeに相談: このUI、どう思う？",
            "Claude式リファクタリング手順",
            "Claudeとブレストしたアプリアイデア",
            "Claude「コミットは小さく、頻繁に」",
            "Claudeが教えてくれたSwiftDataの裏技",
        ]
        let claudeTitles = [
            "Claude語録", "Claudeメモ", "Claude相談", "Claudeレビュー",
            "Claude tips", "", "", // タイトルなしも混ぜる
        ]

        // タグなし + 各親タグにそれぞれ1〜4個ランダムに配置
        let tagOptions: [Tag?] = [nil] + tags.parents
        for tagOption in tagOptions {
            let count = rng.nextInt(4) + 1 // 1〜4個
            for _ in 0..<count {
                let m = Memo(content: rng.pick(claudeTexts), isMarkdown: false)
                m.title = rng.pick(claudeTitles)
                if let tag = tagOption {
                    m.tags.append(tag)
                }
                let daysAgo = Double(rng.nextInt(30))
                m.createdAt = Date().addingTimeInterval(-(daysAgo * 86400))
                m.updatedAt = m.createdAt
                context.insert(m)
            }
        }
    }
}
