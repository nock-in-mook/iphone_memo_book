# 引き継ぎメモ

## 現在の状況
- **feature/tag-suggest-ui** ブランチで作業中（mainからの分岐）
- セッション034でルーレット影の修正＋タグサジェストエンジン基盤＋UI実装途中

### セッション034の主な変更点
- **ルーレット影の修正**:
  - インナーシャドウ左端の隙間を三角関数で正確に計算
  - TagDialViewの.shadow()が上下に漏れる問題 → DialEdgeArcShape（弧形図形）で影を出す方式に変更（クリップ不要）
  - インナーシャドウ調整（7px / opacity 0.3）
  - トレー背景のshadow y:2→0に修正
- **タグサジェストエンジン基盤**:
  - TagFrequency / TagCooccurrence / TagSuggestDismissalモデル作成
  - TagSuggestEngine: 6層スコアリング（辞書/学習/時間帯/連続/共起/否定）
  - メモ確定時に自動学習フック
  - TagSuggestDictionary.jsonをバンドルリソースに登録
- **タグサジェストUI（途中）**:
  - MainViewにオーバーレイ表示（縦3候補）
  - 1秒デバウンス、タグ未選択時のみ表示
  - 設定ON/OFF対応
  - **未解決バグ**: 辞書カテゴリ名とタグ名の文字列比較が失敗（Unicode正規化の疑い）
- **ROADMAP整理**: アイデアメモを各Phaseに統合、不要項目削除

## ブランチ構成
- **main**: ルーレット影修正＋サジェストエンジン基盤まで統合済み
- **feature/tag-suggest-ui**: サジェストUI実装中（デバッグ途中）

## 次のアクション（優先順）
1. **タグサジェストのUnicode問題修正** — カテゴリ名「健康」とタグ名「健康」の比較が失敗する原因を特定・修正
2. デバッグオーバーレイを削除してサジェストUIを完成
3. 辞書の大幅拡張（容量増えてもOK、AI級の精度目標）
4. 存在しないタグのサジェスト→タップで新規作成の仕組み
5. ToDoリストモードの実装（Phase 6）
6. 実機での全体動作確認

## 主要ファイル
- **TagSuggestEngine.swift**: サジェストエンジン本体（Services/）
- **TagFrequency.swift / TagCooccurrence.swift / TagSuggestDismissal.swift**: 学習データモデル（Models/）
- **TagSuggestDictionary.json**: 4449語の事前辞書
- **TagDialView.swift**: ルーレット描画（DialEdgeArcShape影、インナーシャドウ）
- **MemoInputView.swift**: 入力欄、DialEdgeArcShape定義
- **MainView.swift**: サジェストUI統合、デバッグオーバーレイ

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV8
- **デバッグ表示が残ってる**: MainView/TagSuggestEngineにデバッグオーバーレイ・ログあり（リリース前に削除）
