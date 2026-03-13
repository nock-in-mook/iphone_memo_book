# 引き継ぎメモ

## 現在の状況
- Phase 1 実装完了、UI改善進行中
- feature/input-area-expand-and-view-mode ブランチで作業中
- 入力欄の閲覧/編集モード切替を実装（既存メモは閲覧モードで開く、タップで編集開始）
- 「保存」ボタン→「確定」ボタンに変更（編集モードを抜けてキーボードを閉じる）
- ＋ボタンを○囲みに変更（plus.circle）
- タイトルフォントを17pt semiboldに拡大
- グリッドサイズを3×8, 2×6, 2×3, 1×2, 1(全文)の5段階に変更
- 選択削除ボタンを右下に移動（誤タップ防止）
- メモ追加ボタンを「ここにメモ追加」に変更、タグ自動選択対応
- メモカードにdraggable追加
- キーボード表示時にタブが上がる問題を修正（ignoresSafeAreaをGeometryReaderに移動）

## 主要ファイル
- MemoInputView.swift: 閲覧/編集モード切替（isEditing）、確定ボタン、タグダイアル（親+子）
- MemoInputViewModel.swift: loadMemoCounter追加（閲覧モード切替トリガー）
- MainView.swift: ignoresSafeArea(.keyboard)をGeometryReaderに適用、＋ボタンplus.circle
- TabbedMemoListView.swift: グリッド5段階（3×8/2×6/2×3/1×2/全文）、選択削除右下配置、onAddMemoにタグID渡し
- MemoDetailView.swift: 全画面表示・編集（タグルーレット・タップで編集開始）
- TagDialView.swift: Canvas描画ルーレット
- Tag.swift: gridSize, parentTagID
- SokuMemoKunApp.swift: テストデータ生成（sampleDataV4）

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. featureブランチをmainにマージ
2. 実機ビルド・テスト（iPhone 15 Pro Max実機、署名設定が必要）
3. キーボード表示時にタブが上がらないか実機確認
4. ドラッグでメモ移動の動作確認
5. 設定で「子タグルーレットを常に表示」のオンオフ切替
6. マークダウン編集画面のテコ入れ

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発（tagColor, UIPasteboard, UIResponder等）→ビルドは成功する
- NotificationCenter(.switchToTab)でルーレット↔タブ間のクロスビュー通信
