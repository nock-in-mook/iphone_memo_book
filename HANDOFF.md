# 引き継ぎメモ

## 現在の状況
- Phase 1 実装完了、UI改善中
- TagDialView（カジノルーレット風タグ選択）完成
- タグにcolorIndexプロパティ追加、タブ/ルーレット/タグパネルで色統一
- 新規タグ作成機能（+ボタン → カラー選択付きシート）実装済み
- タグ表示: 5文字省略、角丸長方形にルーレットと同じ色
- ボタン行: タグ系(タグパネル+追加ボタン) | アクション系(コピー+保存) を仕切り線で分離
- 表記「タグなし」で統一済み

## 今回の修正内容
- Tag モデルに `colorIndex: Int` プロパティ追加
- SokuMemoKunApp: 共有ModelContainerで既存タグの色を自動振り直し
- MemoInputView: タグ:ラベル左上配置、+ボタンをグレー化、仕切り線追加
- NewTagSheetView 新規作成（タグ名20文字制限、7色カラー選択、プレビュー）
- TabbedMemoListView / TagDialView: tag.colorIndex ベースの色表示に変更
- 表記統一: 「なし」「タグ無し」→「タグなし」

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro (3827F785-169E-4B8F-AF2E-C0E57438C523) ← iOS 17.2
- ビルドコマンド: `xcodebuild -project SokuMemoKun/SokuMemoKun.xcodeproj -scheme SokuMemoKun -destination 'platform=iOS Simulator,id=3827F785-169E-4B8F-AF2E-C0E57438C523' build`

## 次のアクション
1. 全体的なUI polish
2. Phase 2: iCloud/CloudKit設定・同期テスト
3. 実機テスト
4. メモ検索機能
5. アプリアイコン

## 注意点
- DerivedData キャッシュが原因でビルドが反映されないことがある → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*` でクリーンビルド
- DEVELOPMENT_TEAM は空欄 → 実機テスト時にXcodeでApple IDチーム設定が必要
- 既存タグのcolorIndexが全部同じ場合、起動時に自動で色を振り直す処理あり（SokuMemoKunApp.swift）
