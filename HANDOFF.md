# 引き継ぎメモ

## 現在の状況
- **feature/todo-list** ブランチで作業中（mainにはまだマージしていない）
- セッション050でToDoリスト画面の**大改修**を実施

### セッション050の主な変更点

#### インデント帯の改善
- **帯幅を全階層28ptで統一**（緑→紫→オレンジの3色ループ、2周=6階層まで）
- 帯がチェックボックスにかぶらないよう幅調整（indentBase + 12）
- 追加ボタン行にもインデント帯を表示（後に廃止、子タスク追加行は親階層の帯のみ継続）
- インデント帯タップでフォーカス解除+保存（チェックボックス誤タップ防止）

#### チェックボックス改善
- Button→Image+onTapGestureに変更（タップ判定を28x28に厳密に限定）
- 入力中はチェックボックスも無効化

#### メモ機能（インライン）
- メモアイコン: `doc`/`doc.fill`（付箋風・90度回転）、メモあり=紫塗り/なし=線グレー
- 閉じ状態: 付箋アイコン＋1行プレビュー（「メモ:」テキスト廃止）
- 展開時: 閲覧モード→テキストタップで編集モードへ（付箋アイコン付き）
- 新規メモは即編集モード、既存メモは閲覧→編集の2段階
- メモ編集中に右上「完了」ボタン表示
- メモ編集中に他の項目タップ→メモ保存して抜けるだけ
- 全展開でメモも展開（メモあり時は選択ダイアログ: リストのみ/メモも全展開）
- 全収納でメモも閉じる、枠外タップでは閉じない（明示的にアイコン再タップ or 全収納）
- 空メモは保存せず自動で閉じる

#### 展開/折りたたみ
- 展開ボタン: ▶右向き(未展開)/▼下向き(展開中)に統一（標準UI準拠）
- 色: 子あり未展開=青、展開中=オレンジ（子あり・なし問わず）、子なし未展開=薄グレー
- 最深階層では展開ボタン非表示（同サイズの空スペース確保でメモアイコンずれ防止）
- 編集中はメモ/展開ボタンがグレーアウト+disabled

#### 項目追加の改善
- 連続追加モード完全廃止（Enter確定で次行に自動遷移しない）
- 空タイトルはEnter/枠外タップで即削除
- 編集中は+ボタン非表示、確定後に再表示
- 子タスク追加行: 点線枠「+ "○○"  の子タスクを追加」に変更（左寄せ）
- ルート追加: 中央の+ボタン（インデント後の残り幅で中央配置）
- +ボタン/子タスク追加行は.moveDisabled(true)でドラッグ対象外

#### フォーカス管理
- isEditingFocused/isMemoFocusedのonChangeでフォーカス外れ時に自動commitEdit/commitMemo
- 帯タップでもフォーカス解除+保存

#### 全チェッククリア・全タスク削除
- 進捗リングタップで全チェッククリア（確認ダイアログ付き、リング下に「リセット」ヒント）
- ヘッダー長押しで全タスク削除メニュー
- 下端フロートボタンで全タスク削除（2段階確認ダイアログ）
- 進捗算出はルート項目のみ
- 全完了時レインボードーナツ🌈

#### ヒント・案内
- ヒントテキストをList外に移動、編集中は非表示
- +ボタンから距離を取って配置（top 24pt, bottom 50pt）

#### 一覧画面（TodoListsView）
- 2列Pinterest風レイアウト（各カード高さバラバラ）
- ルート項目プレビュー付きカード（最大5件、チェックボックス付き）
- ミニドーナツ(%表示)を右上に、件数を右下に配置
- 全完了時レインボードーナツ+「全完了」テキスト
- 長押しメニュー: トップ移動/固定/ロック/削除
- 削除確認ダイアログ追加
- ピンアイコン(左上オレンジ)、ロックアイコン(左上オレンジ丸)
- ソート: 固定→通常、manualSortOrder→更新日

#### モデル変更
- TodoList: isPinned, isLocked, manualSortOrder追加

#### 爆速モード
- フィルタの展開矢印も右向き/下向き+オレンジに統一

## 次のアクション（優先順）
1. **並び替え問題の大改修**（ドラッグ並び替えが階層を超えて壊れる問題の根本対策）
2. **子タスク追加行の一覧性改善**（テキストが多すぎて邪魔→小さい+だけにする案等）
3. **キーボード表示時のスクロール改善**（まだ下の方の項目が隠れる場合あり）
4. **ToDoリストごとにアイコンと色を選べる機能**
5. **フォルダタブでTODOタグ選択時にTodoItemsを一覧表示**
6. **タグ（バッグ）への紐付けUI**
7. カラーブラインドモード
8. アプリアイコン

## 主要ファイル（ToDo関連）
- **TodoItem.swift**: ToDoデータモデル（listID, parentID, isDone, memo, tags等）
- **TodoList.swift**: リストモデル（id, title, isPinned, isLocked, manualSortOrder）
- **TodoListView.swift**: リスト編集画面（Listベース、スワイプ削除、ドラッグ並び替え、階層色帯、インラインメモ）
- **TodoListsView.swift**: リスト一覧画面（2列Pinterest風、プレビュー付きカード、長押しメニュー）
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
- **チェックボックス**: Image+onTapGestureで28x28に限定（Buttonだとタップ判定が広がる）
