# 引き継ぎメモ

## 現在の状況
- **experiment/frosted-folder** ブランチで作業中
- セッション028でUI大幅改善（テクスチャ・影・タグ操作・Undo等）

### セッション028の主な変更点
- フォルダ背景を一元管理化（テクスチャ・影を一括適用）
- タブ・メモカード・テキストに影追加
- 「このフォルダにメモ作成」を下部中央に移動
- 子タグの自動反映修正（onChange競合）
- フォルダタブ長押しでタグ編集・削除
- Undo/Redoボタン追加
- 入力欄最大化ボタン修正（dialAreaのcontentShape問題）

## ブランチ構成
- **main**: セッション027まで（タグ追加改善・iPad対応・重複警告等）
- **experiment/frosted-folder**: セッション028（テクスチャ・影・UI改善）← 現在

## 主要ファイル
- **TabbedMemoListView.swift**: メモ一覧、フォルダタブ、子タグドロワー、背景一元管理、影ラボ
- **MemoInputView.swift**: 入力欄、Undo/Redo、最大化ボタン修正
- **MainView.swift**: iPad対応、子タグ反映修正
- **MemoInputViewModel.swift**: Undo/Redoスタック、hasText判定
- **TextureLabView.swift**: テクスチャ・影の比較ラボ（設定から開ける）
- **SettingsView.swift**: 影ラボ・タグ色フレーム設定

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)

## 次のアクション
1. ブランチをmainにマージするか判断
2. メモ一覧スクロール時のメモ枚数テキストかぶり修正（ROADMAPに記載）
3. 最近追加したメモ一覧（ROADMAPアイデアメモ）
4. Specialメニュー（爆速整理モード等）
5. その他ROADMAPのタスク

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- テクスチャラボは実機で全パターン1画面表示するとクラッシュ（Stage分割で対応済み）
- CIFilterベースのテクスチャは実機でクラッシュしたため削除済み
