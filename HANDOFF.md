# 引き継ぎメモ

## 現在の状況
- **main** ブランチで作業中
- セッション032でフォルダ並び替えリデザイン・ルーレット改善・タグバッジ刷新を実施

### セッション032の主な変更点
- フォルダ並び替えモードの大幅リデザイン（メモカード非表示、カプセルボタン、ドラッグ中背景色変化）
- 並び替え中のクリップ解除（タブが上にはみ出せる）
- 並び替え中は最大化ボタン非表示
- 完了時のアニメーション＋最後のタブにフォーカス
- experiment/frosted-folderブランチをmainにマージ
- 「よく見る」タブの左右列を同色グラデ＋極小ドロップシャドウに
- カラーラボ追加（設定画面から配色パターンプレビュー）
- ダーク系パレット7色削除（黒テキスト統一）
- ノイズテクスチャ全削除（PaperTextureOverlay等）
- ルーレット: セクター色を完全不透明、テキスト色で選択/非選択を区別
- ルーレット: context.resolve+measureでフォントサイズ実測フィット
- タグバッジ: 親子めり込みデザイン（下端揃え）
- タグバッジ: 半角幅換算で文字数制限
- タグバッジ: 子タグに白い縁取り
- 子タグ編集プレビューを角丸長方形に修正

## ブランチ構成
- **main**: 全作業統合済み（experiment/frosted-folderマージ完了）

## 主要ファイル
- **TabbedMemoListView.swift**: メモ一覧、フォルダタブ、子タグドロワー、並び替えモード、よく見る配色、conditionalClipped
- **MemoInputView.swift**: 入力欄、タグバッジ（親子めり込みデザイン）、truncateByWidth
- **TagDialView.swift**: ルーレット、セクター不透明化、resolve+measureフィット
- **MainView.swift**: 並び替えモード連携（isTabReorderMode）
- **ColorLabView.swift**: カラーラボ（12パターン×10色）
- **SettingsView.swift**: カラーラボへのリンク追加

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)

## 次のアクション
1. 実機での全体動作確認
2. Specialメニュー（爆速整理モード等）
3. その他ROADMAPのタスク

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV8
