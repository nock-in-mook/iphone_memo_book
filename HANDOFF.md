# 引き継ぎメモ

## 現在の状況
- **feature/todo-list** ブランチで作業中（mainにはまだマージしていない）
- セッション049でToDoリスト画面の**大改修**を実施

### セッション049の主な変更点

#### LazyVStack → List 完全移行（最重要）
- **ScrollView + LazyVStack** から **List** に完全移行
- LazyVStackに自前DragGestureを載せるとScrollViewのスクロールが死ぬ問題を根本解決
- Listネイティブの機能をフル活用:
  - **左スワイプ削除**: `.swipeActions`
  - **長押しドラッグ並び替え**: `.onMove` (EditMode不要で動く)
  - **スクロール**: Listネイティブ
- `.listStyle(.plain)` + `.scrollContentBackground(.hidden)` + `.listRowSeparator(.hidden)` + `.listRowBackground(.clear)` でカスタムスタイル維持

#### UI見た目の変更
- **カード背景(角丸グレー/緑) → 廃止**: 下部に細い区切り線のみ
- **丸チェック → 四角チェックボックス**: `checkmark.square.fill` / `square`、28pt太め
- **フォント**: 丸ゴシック Medium 15pt（フォントラボで選定）
- **階層色帯**: L字ツリーラインを廃止、代わりにインデント部分を階層ごとに色分け
  - ルート: パステルグリーン(0.12)
  - 子階層1: パステル紫(0.10)
  - 子階層2以降: 青→オレンジ
- **行高さ縮小**: padding .vertical 0pt + defaultMinListRowHeight 1pt

#### 項目追加の改善
- **常時入力欄 → +ボタン方式**: 小さい⊕ボタンだけ表示、タップで空行追加
- **空行カーソル方式**: +で空TodoItem作成→即インライン編集→Enter連続入力→空Enterで終了
- **空タイトル防止**: save()遅延 + onAppear/戻るでcleanupEmptyItems()

#### その他
- **完了ボタン**: ナビバー右上（編集中のみ表示）
- **枠外タップ**: .onTapGesture で編集終了 + キーボード閉じ
- **フォントラボ**: 設定画面に追加（デザイン×ウェイト×サイズの大量プレビュー）

## 次のアクション（優先順）
1. **階層色帯の色味調整**（ユーザーが確認中）
2. **ToDoリストごとにアイコンと色を選べる機能**
3. **フォルダタブでTODOタグ選択時にTodoItemsを一覧表示**
4. **タグ（バッグ）への紐付けUI**
5. カラーブラインドモード
6. アプリアイコン

## 主要ファイル（ToDo関連）
- **TodoItem.swift**: ToDoデータモデル（listID, parentID, isDone, tags等）
- **TodoList.swift**: リストモデル（id, title）
- **TodoListView.swift**: リスト編集画面（Listベース、スワイプ削除、ドラッグ並び替え、階層色帯）
- **TodoListsView.swift**: リスト一覧画面（緑TODOタブ、白カード）
- **FontLabView.swift**: フォントラボ（設定内、大量プレビュー）
- **IconLabView.swift**: アイコンラボ（設定内）

## 主要ファイル（爆速モード関連）
- **QuickSortCellView.swift**: セル（カード+ルーレットのみ、コントローラーは外）— キーボード高さ監視もここ
- **QuickSortView.swift**: メイン画面（フェーズ管理・カルーセル・コントローラーエリア・操作パネル・各種ダイアログ）
- **QuickSortFilterView.swift**: 事前フィルタ選択シート
- **ButtonLabView.swift**: アニメ塗りボタンラボ（16パターン×3色）+ PressableButtonStyle / TapPressableView定義
- **QuickSortResultView.swift**: 戦績画面
- **CarouselView.swift**: UICollectionViewベースのカルーセル
- **TagDialView.swift**: ルーレット
- **TrapezoidTabShape.swift**: 各種Shape定義
- **TappableReadOnlyText.swift**: 閲覧モード用タップ位置検出テキスト表示
- **LineNumberTextEditor.swift**: 行番号付きエディタ（initialCursorOffset対応）

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro (iOS 26.3)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **実機ビルド**: 証明書は別Macから.p12エクスポートでインポート済み、`-allowProvisioningUpdates` フラグ必要
- **ブランチ**: feature/todo-list（mainにマージ前）

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV10 + longTextTestV2
- **ダイアログルール**: 全てカスタムリッチダイアログ（標準alertは使わない）
- **SwiftUI再帰ViewBuilder制約**: ツリー表示はフラット化して対応
- **キーボードとダイアログ**: ダイアログはNavigationStack外のZStackに配置（押し潰れ防止）
- **LazyVStack + DragGesture は使わない**: ScrollViewのスクロールが死ぬ。Listを使うこと
