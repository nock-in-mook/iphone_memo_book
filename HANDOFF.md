# 引き継ぎメモ

## 現在の状況
- **experiment/frosted-folder** ブランチで作業中
- セッション029でメモ枚数スクロールかぶり修正、「よく見る」フォルダ追加、特殊タブ色変更等を実装

### セッション029の主な変更点
- メモ枚数表示のスクロール時かぶり修正（不透明背景+zIndex調整）
- メモ一覧の上余白をドロワー高さに連動
- メモ開閉アニメーション時短（開く0.2s、戻るアニメなし）
- 親タグ-子タグバッジ表示（子タグフィルター中）
- 最後に開いたメモのうっすら水色ハイライト
- 「よく見る」タブ追加（左: よく見る順、右: 最近見た順の2列表示）
- Memoモデルに viewCount / lastViewedAt 追加
- 「すべて」「よく見る」タブの長押し色変更（カラーパレットシート）
- SpecialColorEditSheet独立View化（sheet再利用バグ修正）
- 長押しメニュー順序変更（フォルダ並び替えを最上部に）

## ブランチ構成
- **main**: セッション027まで
- **experiment/frosted-folder**: セッション028-029（テクスチャ・影・UI改善・よく見るフォルダ）← 現在

## 主要ファイル
- **TabbedMemoListView.swift**: メモ一覧、フォルダタブ、子タグドロワー、背景一元管理、よく見るタブ、色変更シート
- **MemoInputView.swift**: 入力欄、Undo/Redo、最大化ボタン修正
- **MainView.swift**: iPad対応、子タグ反映修正、アニメーション時短
- **MemoInputViewModel.swift**: Undo/Redoスタック、hasText判定、閲覧追跡
- **Memo.swift**: viewCount / lastViewedAt 追加
- **TagEditView.swift**: ColorPaletteGrid、TagDetailEditView

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)

## 次のアクション
1. **通常タグの編集プレビューをリアルなタブデザインに**: TagDetailEditViewのプレビューを、TrapezoidTabShape+ドロップシャドウ+テクスチャドット付きの実際のタブと同じ見た目にする（SpecialColorEditSheetと同じ方式）
2. **タブの並び替えグラフィカルモード**: 長押し→「フォルダの並び替え」→タブバー上で直接ドラッグ（ぷるぷるアニメ、完了ボタン）
2. ブランチをmainにマージするか判断
3. Specialメニュー（爆速整理モード等）
4. その他ROADMAPのタスク

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **sheet(isPresented:)のState再利用バグ**: 特殊タブ色変更で発覚。sheet(item:)+独立Viewで解決済み
- **ForEach(0..<count, id: \.self)のcontextMenuキャプチャ問題**: indexが古い値を保持する場合がある
