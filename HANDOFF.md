# 引き継ぎメモ

## 現在の状況
- **experiment/frosted-folder** ブランチで作業中
- セッション031でロック機能・タブドラッグ並び替え・各種UI改善を実装

### セッション031の主な変更点
- メモカードの削除防止ロック機能（isLocked、鍵マーク、トースト表示、タグ削除時のロック中メモ保護）
- フォルダタブのドラッグ並び替え（ぷるぷるモード、浮遊タブ、自動スクロール、触覚フィードバック）
- タグ付け取っ手の右スワイプ完全収納・左スワイプ全開
- ルーレットにドロップシャドウ追加（トレー側レイヤーで描画）
- すべて・よく見るタブのメモ作成ボタン非表示
- グリッドボタン色をゴミ箱と統一（.tint(.secondary)）
- タブ背景テクスチャをタブ行から除外（隙間からノイズが見えてた問題修正）
- 選択中タブのscaleEffect(1.08)で拡大表示
- タブシャドウをシャープに調整

### 解決済み: シートの伸び縮み問題
- iOS 26シミュレータ固有のバグと確認（セッション031で実機検証済み）
- **実機では発生しない** → 対応不要

## ブランチ構成
- **main**: セッション027まで
- **experiment/frosted-folder**: セッション028-031（テクスチャ・影・UI改善・よく見るフォルダ・タグ編集改善・ロック機能・ドラッグ並び替え）← 現在

## 主要ファイル
- **TabbedMemoListView.swift**: メモ一覧、フォルダタブ、子タグドロワー、背景一元管理、よく見るタブ、色変更シート、ロック機能、タブドラッグ並び替え
- **MemoInputView.swift**: 入力欄、Undo/Redo、最大化ボタン修正、ルーレットスワイプ収納
- **MainView.swift**: iPad対応、子タグ反映修正、アニメーション時短
- **MemoInputViewModel.swift**: Undo/Redoスタック、hasText判定、閲覧追跡
- **Memo.swift**: viewCount / lastViewedAt / isLocked 追加
- **TagEditView.swift**: ColorPaletteGrid、TagDetailEditView（リアルタブプレビュー）、ドラッグ並び替え
- **NewTagSheetView.swift**: 親タグ時リアルタブプレビュー
- **TagDialView.swift**: ルーレット描画、ドロップシャドウ（トレー側で描画）

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)

## 次のアクション
1. **選択中タブのscaleEffectアニメーションもたつき** → 実機で確認してから対応判断
2. **タブの並び替えグラフィカルモードの微調整**（実機での挙動確認）
3. ブランチをmainにマージするか判断
4. Specialメニュー（爆速整理モード等）
5. その他ROADMAPのタスク

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **sheet(isPresented:)のState再利用バグ**: 特殊タブ色変更で発覚。sheet(item:)+独立Viewで解決済み
- **ForEach(0..<count, id: \.self)のcontextMenuキャプチャ問題**: indexが古い値を保持する場合がある
- **テストデータバージョン**: sampleDataV8
