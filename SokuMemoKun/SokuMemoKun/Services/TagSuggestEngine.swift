import Foundation
import SwiftData

// タグサジェストエンジン（ローカル完結・AI不要）
// 3層構造: ①事前辞書 ②ユーザー学習 ③直近パターン
// + 時間帯加重 + 共起タグ + 否定学習
@Observable
class TagSuggestEngine {
    // 事前辞書（キーワード→カテゴリ名の配列）
    private var dictionary: [String: [String]] = [:]
    // 直近使用したタグID（連続入力パターン用）
    private(set) var recentTagIDs: [UUID] = []
    private let maxRecent = 10

    init() {
        loadDictionary()
    }

    // MARK: - 辞書読み込み

    private func loadDictionary() {
        guard let url = Bundle.main.url(forResource: "TagSuggestDictionary", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String]]
        else { return }
        // 全キーを小文字正規化（重複キーは値をマージ）
        dictionary = Dictionary(dict.map { (key, value) in
            (key.lowercased(), value)
        }, uniquingKeysWith: { existing, new in
            Array(Set(existing + new))
        })
    }

    // MARK: - サジェスト取得（メイン）

    // サジェストの種類
    enum SuggestionKind: Equatable {
        case dictMatch    // おすすめタグ（辞書マッチ）
        case newTag       // 新規タグ提案
        case history      // 履歴から
    }

    struct Suggestion: Identifiable, Equatable {
        let id: UUID
        let parentID: UUID?     // 親タグのID（新規タグ提案時はnil）
        let parentName: String  // 親タグ名（新規タグ提案時は提案名）
        let childID: UUID?      // 子タグのID
        let childName: String?  // 子タグ名
        var score: Double
        let kind: SuggestionKind

        init(id: UUID, parentID: UUID? = nil, parentName: String,
             childID: UUID? = nil, childName: String? = nil,
             score: Double, kind: SuggestionKind = .dictMatch) {
            self.id = id
            self.parentID = parentID
            self.parentName = parentName
            self.childID = childID
            self.childName = childName
            self.score = score
            self.kind = kind
        }

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
            if lhs.kind == .newTag && rhs.kind == .newTag {
                return lhs.parentName == rhs.parentName
            }
            return lhs.parentID == rhs.parentID && lhs.childID == rhs.childID
        }
    }

    func suggest(
        title: String,
        body: String,
        tags: [Tag],
        context: ModelContext,
        limit: Int = 3
    ) -> [Suggestion] {
        // テキストから単語を抽出
        let words = extractWords(from: title, body: body)
        guard !words.isEmpty || !recentTagIDs.isEmpty else { return [] }

        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)

        var scores: [UUID: Double] = [:]
        var tagNames: [UUID: String] = [:]

        // タグ名のルックアップテーブル
        for tag in tags {
            tagNames[tag.id] = tag.name
        }

        // ① 事前辞書マッチ（完全一致＋部分一致）
        var newTagCandidates: [String: Double] = [:] // 新規タグ候補（カテゴリ名→スコア）
        for word in words {
            let key = word.lowercased()
            // 完全一致
            if let categories = dictionary[key] {
                for category in categories {
                    var matched = false
                    for tag in tags {
                        let nameMatch = tag.name == category
                        let nameContainsCat = tag.name.contains(category)
                        let catContainsName = category.contains(tag.name)
                        if nameMatch || nameContainsCat || catContainsName {
                            scores[tag.id, default: 0] += 1.0
                            matched = true
                        }
                    }
                    if !matched {
                        // 既存タグに無いカテゴリ → 新規タグ候補に追加
                        newTagCandidates[category, default: 0] += 1.0
                    }
                }
            }
            // 部分一致: 入力単語が辞書キーを含む or 辞書キーが入力単語を含む
            // ノイズ防止: 両方3文字以上で、短い方が長い方の50%以上の長さの場合のみ
            if key.count >= 3 {
                for (dictKey, categories) in dictionary {
                    guard key != dictKey && dictKey.count >= 3 else { continue }
                    let shorter = min(key.count, dictKey.count)
                    let longer = max(key.count, dictKey.count)
                    guard shorter * 2 >= longer else { continue } // 短い方が長い方の半分以上
                    if key.contains(dictKey) || dictKey.contains(key) {
                        for category in categories {
                            for tag in tags where tag.name == category || tag.name.contains(category) || category.contains(tag.name) {
                                scores[tag.id, default: 0] += 0.5 // 部分一致は低めのスコア
                            }
                        }
                    }
                }
            }
        }

        // 辞書マッチのスコアを保存（履歴と分離するため）
        let dictScores = scores

        // ② ユーザー学習（TagFrequency）
        var historyScores: [UUID: Double] = [:]
        let frequencyScores = queryFrequencies(words: words, context: context)
        for (tagID, freq) in frequencyScores {
            scores[tagID, default: 0] += freq
            historyScores[tagID, default: 0] += freq
        }

        // 時間帯加重
        let timeScores = queryTimeBoost(hour: currentHour, weekday: currentWeekday, context: context)
        for (tagID, boost) in timeScores {
            scores[tagID, default: 0] += boost
            historyScores[tagID, default: 0] += boost
        }

        // ③ 連続入力パターン
        if !recentTagIDs.isEmpty {
            for (i, tagID) in recentTagIDs.reversed().enumerated() {
                let boost = 2.0 / Double(i + 1)
                scores[tagID, default: 0] += boost
                historyScores[tagID, default: 0] += boost
            }
        }

        // 共起タグ加重
        let coocScores = queryCooccurrence(currentTags: Array(scores.keys), context: context)
        for (tagID, boost) in coocScores {
            scores[tagID, default: 0] += boost
            historyScores[tagID, default: 0] += boost
        }

        // 否定学習（スコア減算）
        let dismissals = queryDismissals(words: words, context: context)
        for (tagID, penalty) in dismissals {
            scores[tagID, default: 0] -= penalty
            historyScores[tagID, default: 0] -= penalty
        }

        // 親タグと子タグを分類
        let parentTags = tags.filter { $0.parentTagID == nil }
        let childTags = tags.filter { $0.parentTagID != nil }

        // === セクション1: おすすめタグ（辞書マッチあり） ===
        var dictResults: [Suggestion] = []
        let dictParentScores: [(tag: Tag, score: Double)] = parentTags
            .compactMap { tag in
                let s = dictScores[tag.id, default: 0]
                return s > 0 ? (tag, s) : nil
            }
            .sorted { $0.score > $1.score }

        for (parent, parentScore) in dictParentScores.prefix(limit) {
            let children = childTags.filter { $0.parentTagID == parent.id }
            let scoredChildren = children
                .compactMap { child -> (tag: Tag, score: Double)? in
                    let s = dictScores[child.id, default: 0]
                    return s > 0 ? (child, s) : nil
                }
                .sorted { $0.score > $1.score }

            for child in scoredChildren {
                dictResults.append(Suggestion(
                    id: UUID(), parentID: parent.id, parentName: parent.name,
                    childID: child.tag.id, childName: child.tag.name,
                    score: parentScore + child.score, kind: .dictMatch
                ))
            }
            dictResults.append(Suggestion(
                id: UUID(), parentID: parent.id, parentName: parent.name,
                score: parentScore, kind: .dictMatch
            ))
        }

        // === セクション2: 新規タグ提案 ===
        var newTagResults: [Suggestion] = []
        for (name, score) in newTagCandidates.sorted(by: { $0.value > $1.value }).prefix(limit) {
            newTagResults.append(Suggestion(
                id: UUID(), parentName: name, score: score, kind: .newTag
            ))
        }

        // === セクション3: 履歴から（辞書マッチが無いがスコアがあるタグ） ===
        var histResults: [Suggestion] = []
        let histParentScores: [(tag: Tag, score: Double)] = parentTags
            .compactMap { tag in
                let s = historyScores[tag.id, default: 0]
                // 辞書マッチ済みのものは除外
                return s > 0 && dictScores[tag.id, default: 0] <= 0 ? (tag, s) : nil
            }
            .sorted { $0.score > $1.score }

        for (parent, parentScore) in histParentScores.prefix(limit) {
            let children = childTags.filter { $0.parentTagID == parent.id }
            let bestChild = children
                .compactMap { child -> (tag: Tag, score: Double)? in
                    let s = historyScores[child.id, default: 0]
                    return s > 0 ? (child, s) : nil
                }
                .sorted { $0.score > $1.score }
                .first

            if let child = bestChild {
                histResults.append(Suggestion(
                    id: UUID(), parentID: parent.id, parentName: parent.name,
                    childID: child.tag.id, childName: child.tag.name,
                    score: parentScore + child.score, kind: .history
                ))
            }
            histResults.append(Suggestion(
                id: UUID(), parentID: parent.id, parentName: parent.name,
                score: parentScore, kind: .history
            ))
        }

        // 3セクションを結合して返す（各セクションlimit件まで）
        var results: [Suggestion] = []
        results.append(contentsOf: dictResults.prefix(limit))
        results.append(contentsOf: newTagResults.prefix(limit))
        results.append(contentsOf: histResults.prefix(limit))
        return results
    }

    // MARK: - 単語抽出

    private func extractWords(from title: String, body: String) -> [String] {
        // タイトル全体 + 本文先頭200文字から単語を抽出
        let text = title + " " + String(body.prefix(200))
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var words: [String] = []
        // CFStringTokenizer で日本語の形態素解析
        // ※ CFStringTokenizerはUTF-16単位で動作するため、NSString.lengthを使う
        let cfStr = trimmed as CFString
        let utf16Len = CFStringGetLength(cfStr)
        let tokenizer = CFStringTokenizerCreate(
            nil, cfStr,
            CFRangeMake(0, utf16Len),
            kCFStringTokenizerUnitWord,
            CFLocaleCopyCurrent()
        )
        let utf16 = trimmed.utf16
        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while tokenType != [] {
            if let token = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String {
                // ラテン転写も辞書キーとして使う
                words.append(token.lowercased())
            }
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            // UTF-16インデックスで正確に部分文字列を取得
            let startIdx = utf16.index(utf16.startIndex, offsetBy: range.location)
            let endIdx = utf16.index(startIdx, offsetBy: range.length)
            if let word = String(utf16[startIdx..<endIdx]), word.count >= 2 {
                words.append(word.lowercased())
            }
            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return Array(Set(words)) // 重複排除
    }

    // MARK: - ユーザー学習クエリ

    private func queryFrequencies(words: [String], context: ModelContext) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        guard !words.isEmpty else { return result }
        let descriptor = FetchDescriptor<TagFrequency>()
        guard let all = try? context.fetch(descriptor) else { return result }
        for freq in all {
            if words.contains(freq.word.lowercased()) {
                // 頻度に基づくスコア（対数スケールで上限を抑える）
                let score = log2(Double(freq.count) + 1) * 0.5
                result[freq.tagID, default: 0] += score
            }
        }
        return result
    }

    private func queryTimeBoost(hour: Int, weekday: Int, context: ModelContext) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        let descriptor = FetchDescriptor<TagFrequency>()
        guard let all = try? context.fetch(descriptor) else { return result }
        for freq in all where freq.hour >= 0 {
            // 時間帯が±2時間以内ならブースト
            let hourDiff = abs(freq.hour - hour)
            let adjustedDiff = min(hourDiff, 24 - hourDiff) // 環状の距離
            if adjustedDiff <= 2 {
                let boost = 0.3 * Double(freq.count) / Double(adjustedDiff + 1)
                result[freq.tagID, default: 0] += boost
            }
            // 同じ曜日ならブースト
            if freq.weekday == weekday {
                result[freq.tagID, default: 0] += 0.2 * Double(freq.count)
            }
        }
        return result
    }

    private func queryCooccurrence(currentTags: [UUID], context: ModelContext) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        guard !currentTags.isEmpty else { return result }
        let descriptor = FetchDescriptor<TagCooccurrence>()
        guard let all = try? context.fetch(descriptor) else { return result }
        for cooc in all {
            for tagID in currentTags {
                if cooc.tagID1 == tagID {
                    result[cooc.tagID2, default: 0] += log2(Double(cooc.count) + 1) * 0.3
                } else if cooc.tagID2 == tagID {
                    result[cooc.tagID1, default: 0] += log2(Double(cooc.count) + 1) * 0.3
                }
            }
        }
        return result
    }

    private func queryDismissals(words: [String], context: ModelContext) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        guard !words.isEmpty else { return result }
        let descriptor = FetchDescriptor<TagSuggestDismissal>()
        guard let all = try? context.fetch(descriptor) else { return result }
        for d in all {
            if words.contains(d.word.lowercased()) {
                result[d.tagID, default: 0] += Double(d.count) * 0.5
            }
        }
        return result
    }

    // MARK: - 学習（メモ保存時に呼ぶ）

    func learn(title: String, body: String, tagIDs: [UUID], context: ModelContext) {
        let words = extractWords(from: title, body: body)
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // 単語×タグの頻度を更新
        for word in words {
            for tagID in tagIDs {
                let key = word.lowercased()
                // 既存レコードを検索
                let descriptor = FetchDescriptor<TagFrequency>(
                    predicate: #Predicate { $0.word == key && $0.tagID == tagID }
                )
                if let existing = try? context.fetch(descriptor).first {
                    existing.count += 1
                    existing.hour = hour
                    existing.weekday = weekday
                    existing.lastUsedAt = now
                } else {
                    let freq = TagFrequency(word: key, tagID: tagID, hour: hour, weekday: weekday)
                    context.insert(freq)
                }
            }
        }

        // 共起タグを更新
        if tagIDs.count >= 2 {
            for i in 0..<tagIDs.count {
                for j in (i+1)..<tagIDs.count {
                    let id1 = tagIDs[i].uuidString < tagIDs[j].uuidString ? tagIDs[i] : tagIDs[j]
                    let id2 = tagIDs[i].uuidString < tagIDs[j].uuidString ? tagIDs[j] : tagIDs[i]
                    let descriptor = FetchDescriptor<TagCooccurrence>(
                        predicate: #Predicate { $0.tagID1 == id1 && $0.tagID2 == id2 }
                    )
                    if let existing = try? context.fetch(descriptor).first {
                        existing.count += 1
                        existing.lastUsedAt = now
                    } else {
                        let cooc = TagCooccurrence(tagID1: id1, tagID2: id2)
                        context.insert(cooc)
                    }
                }
            }
        }

        // 直近タグを更新
        for tagID in tagIDs {
            recentTagIDs.removeAll { $0 == tagID }
            recentTagIDs.append(tagID)
        }
        if recentTagIDs.count > maxRecent {
            recentTagIDs.removeFirst(recentTagIDs.count - maxRecent)
        }
    }

    // MARK: - 否定学習（サジェスト却下時に呼ぶ）

    func dismiss(word: String, tagID: UUID, context: ModelContext) {
        let key = word.lowercased()
        let descriptor = FetchDescriptor<TagSuggestDismissal>(
            predicate: #Predicate { $0.word == key && $0.tagID == tagID }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.count += 1
            existing.lastDismissedAt = Date()
        } else {
            let d = TagSuggestDismissal(word: key, tagID: tagID)
            context.insert(d)
        }
    }
}
