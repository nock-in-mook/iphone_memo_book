# 引き継ぎメモ

## 現在の状況
- Phase 1 実装完了、UI改善進行中
- 設定画面（⚙️）実装済み: タグ編集、マークダウン設定、バックアップ(準備中)、最大文字数(準備中)
- タグ編集機能: 一覧表示(背景色付き)、タップで編集、新規追加、選択削除
- カラーパレット: 28色(7×4グリッド)に拡張
- マークダウン編集機能: 全画面エディタ、ON/OFFトグル、上下分割/タブ切替プレビュー
- デフォルトマークダウンON設定: 設定変更→即反映、保存後リセット
- マークダウンON＋空欄タップで全画面編集を自動起動（ガイドテキスト付き）
- `.buttonStyle(.plain)` でSwiftUIのButton青色問題を全面解決

## 主要ファイル（今回追加・変更）
- SettingsView.swift: 設定画面
- TagEditView.swift: タグ編集（一覧、詳細編集、カラーパレット、プレビュー）
- NewTagSheetView.swift: 新規タグ作成シート
- FullEditorView.swift: マークダウン全画面エディタ（MarkdownLayout enum含む）
- MemoInputView.swift: マークダウンON時の空欄タップ→全画面編集
- MemoInputViewModel.swift: isMarkdown保存後リセット
- MainView.swift: 設定画面表示、defaultMarkdown onChange連携

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- ビルドコマンド: `xcodebuild -project SokuMemoKun/SokuMemoKun.xcodeproj -scheme SokuMemoKun -destination 'platform=iOS Simulator,id=95C8A8C5-0972-4BB0-B793-5219096697DF' build`

## 次のアクション
1. マークダウン編集画面の改善（より直感的なUI）
2. タブごとのグリッド表示切替（1列/2列/コンパクト等）
3. 爆速振り分けモード（フリック×タグホイール連動のタグ付け/削除）
4. Googleドライブバックアップ機能
5. メモ最大文字数設定
6. メモカードの長文対応
7. Phase 2: iCloud/CloudKit設定・同期テスト
8. 実機テスト

## 注意点
- DerivedData キャッシュが原因でビルドが反映されないことがある → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*` でクリーンビルド
- DEVELOPMENT_TEAM は空欄 → 実機テスト時にXcodeでApple IDチーム設定が必要
- 既存タグのcolorIndexが全部同じ場合、起動時に自動で色を振り直す処理あり（SokuMemoKunApp.swift）
- SwiftUIのButton内テキストが青くなる問題 → `.buttonStyle(.plain)` で解決
- MemoInputViewModelは@Stateで一度だけ生成されるため、設定変更はonChangeで反映する
