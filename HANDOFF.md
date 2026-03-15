# 引き継ぎメモ

## 現在の状況
- **feature/roulette-redesign** ブランチで作業中
- セッション018で多数のUI改善を実施

### 今回の変更点
- フッターに「閉じる」ボタン追加（既存メモ表示時のみ）
- 「ここに保存」ボタンの誤タップ対策
  - コンパクト時（入力欄展開）: 「記入中のメモをここに保存」＋確認ダイアログ
  - 全画面時（入力欄非展開）: 「このタグにメモ作成」（新規作成専用）
  - MemoDetailView: フッターに「ここに保存」＋確認ダイアログ
- 入力欄とフォルダタブの間に30ptスペース確保（誤タップ防止＋将来のSpecialメニュー用）
- ボタンUI改善
  - ゴミ箱を左下、グリッドを右下に配置変更
  - ボタン背景をsystemGray6＋枠線1.0pt
  - 取消ボタンを青背景＋白文字で視認性向上
- 子タグドロワーUI完成
  - 取っ手とトレーの高さ分離（取っ手23pt、トレー36pt）
  - 選択中の子タグに内側白枠線（strokeBorder）
  - 横スクロール対応（子タグが多くても全部アクセス可能）
  - 収納タップを取っ手部分のみに限定
  - 開いてる時は右向き矢印のみ表示、取っ手幅を狭く
  - 追加ボタンを一番右に移動
- 子タグ連打フリーズ修正（アニメーション競合解消）
- グラデーション背景をベタ塗りに変更
- 仕事タグに子タグ15個のテストデータ追加（sampleDataV7）

## ブランチ構成
- **main**: 安定版
- **feature/input-area-expand-and-view-mode**: 展開/縮小・タグタブ改善（マージ待ち）
- **feature/roulette-redesign**: ルーレット統合Canvas・UI改善・子タグドロワー（現在作業中）

## 主要ファイル
- MemoInputView.swift: 展開/縮小、逆さL字タグタブ（「タグ付」表記）、フッター（閉じるボタン追加）
- MemoInputViewModel.swift: loadMemoCounter（閲覧モード切替トリガー）
- MainView.swift: isInputExpanded状態管理、展開時←ボタン、30ptスペース、確認ダイアログ
- TabbedMemoListView.swift: グリッド5段階、isCompact対応、ボタンUI改善、子タグドロワー完成、横スクロール対応
- TagDialView.swift: 親子統合Canvas（1つのCanvasで親子描画）
- MemoDetailView.swift: 統合TagDialView対応済み、フッターに「ここに保存」＋確認ダイアログ
- SokuMemoKunApp.swift: テストデータV7（仕事に子タグ15個）

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. Specialメニュー実装（30ptスペースからの引き出し）
2. feature/roulette-redesignをfeature/input-area-expand-and-view-modeにマージ
3. さらにmainにマージ
4. 実機ビルド・テスト
5. テストデータ（sampleDataV7）を元に戻す or 調整
6. FullEditorView.swift / MemoDetailView.swiftの不要コード整理
7. 設定で「子タグルーレットを常に表示」のオンオフ切替
8. ルーレット上のマス長押しでタグ削除メニュー
9. マークダウン編集画面のテコ入れ
10. 横画面対応、iPad対応レイアウト、アプリアイコン

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **実機ビルドキャッシュ問題**: DerivedDataクリーンでも実機に古いビルドが残ることがある。`xcodebuild clean` + フルリビルドが確実
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- **SwiftUIのZStack内Buttonのタップ領域問題**: ZStack内のButtonは周囲の空白もタップ対象になる。ダミー枠（padding+background）で見た目をタップ領域に合わせるアプローチが有効
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発（tagColor, UIPasteboard, UIResponder等）→ビルドは成功する
- NotificationCenter(.switchToTab, .memoSavedFlash)でクロスビュー通信
- タブインデックスはsortOrderベース（name sortではない）
- タグタブのoverlayは本文ZStackの.topTrailingに配置（仕切り線直下）
- TagDialViewは親子統合Canvas: ドラッグx座標で親/子判定（borderX = cx - parentInnerR）
- switchToTabはルーレット操作では発火しない（新タグ作成時のみ）
- **子タグ連打フリーズ**: withAnimationの競合が原因。子タグタップのwithAnimationを除去、.animation(.spring)のスコープをドロワーのみに限定して解決
