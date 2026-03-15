# 引き継ぎメモ

## 現在の状況
- **feature/roulette-redesign** ブランチで作業中（feature/input-area-expand-and-view-modeから派生）
- 親子ルーレットを1つのCanvasに統合（親の内周=子の外周がぴったり接する）
- ルーレットから「+追加」マスを削除、ルーレット下部に追加ボタン配置
- 「確定」ボタン廃止→「記入中のメモをここに保存」ボタンに統一（タブ下に配置）
- 保存時にタブ+カードのフラッシュアニメーション追加
- 全画面展開時に左上ボタンが「←」（縮小）に切替
- 全画面展開時はツールバー（枚数・選択削除）非表示、「ここに保存」ボタンのみ
- タグタブの色を薄いグレーに変更（0.76）
- ゴミ箱アイコン15pt
- 本文入力欄の余白調整（上16pt、左右均等）
- テキスト下端に2行分の余白（編集・閲覧両方）
- 展開ボタンを本文入力欄の内側右下に移動（青丸+2方向矢印+ドロップシャドウ）
- ルーレット展開時のテキスト縮小幅をルーレット実幅に連動
- 子ルーレット内周の弧がCanvas高さで切れないよう角度範囲を自動計算

## ブランチ構成
- **main**: 安定版
- **feature/input-area-expand-and-view-mode**: 展開/縮小・タグタブ改善（マージ待ち）
- **feature/roulette-redesign**: ルーレット統合Canvas・UI改善（現在作業中）

## 主要ファイル
- MemoInputView.swift: 展開/縮小、逆さL字タグタブ、フッター（ゴミ箱+コピー）
- MemoInputViewModel.swift: loadMemoCounter（閲覧モード切替トリガー）
- MainView.swift: isInputExpanded状態管理、展開時←ボタン、タグQuery追加
- TabbedMemoListView.swift: グリッド5段階、isCompact対応、「ここに保存」ボタン、フラッシュアニメーション
- TagDialView.swift: 親子統合Canvas（1つのCanvasで親子描画、ドラッグ位置で親子判定）
- MemoDetailView.swift: 統合TagDialView対応済み

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. feature/roulette-redesignをfeature/input-area-expand-and-view-modeにマージ
2. さらにmainにマージ
3. 実機ビルド・テスト
4. FullEditorView.swift / MemoDetailView.swiftの不要コード整理
5. 設定で「子タグルーレットを常に表示」のオンオフ切替
6. タグ選択時にフォルダ自動移動しない設定オプション
7. ルーレット上のマス長押しでタグ削除メニュー
8. マークダウン編集画面のテコ入れ
9. 横画面対応、iPad対応レイアウト、アプリアイコン

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発（tagColor, UIPasteboard, UIResponder等）→ビルドは成功する
- NotificationCenter(.switchToTab, .memoSavedFlash)でクロスビュー通信
- タブインデックスはsortOrderベース（name sortではない）
- タグタブのoverlayは本文ZStackの.topTrailingに配置（仕切り線直下）
- TagDialViewは親子統合Canvas: ドラッグx座標で親/子判定（borderX = cx - parentInnerR）
