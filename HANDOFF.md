# 引き継ぎメモ

## 現在の状況
- **feature/todo-list** ブランチで作業中（mainにはまだマージしていない）
- feature/uikit-carouselはセッション047でmainにマージ済み
- セッション047で**ToDoリスト機能の基盤**を実装

### セッション047の主な変更点

#### ToDoリスト機能の基盤実装
- **TodoItem.swift**: 新規SwiftDataモデル（id, title, isDone, parentID, sortOrder, tags, dueDate, memo）
- **Tag.swift**: `todoItems: [TodoItem]` リレーション追加（メモと同じタグをToDoでも共有）
- **TodoListView.swift**: 新規画面
  - フラット化ツリー表示（再帰をフラット化してSwiftUIのViewBuilder制約を回避）
  - リストタイトル入力
  - 「+ 項目を追加」行でEnter連続入力
  - チェックボックス（チェック→取り消し線）
  - ▶/▼ 展開/折りたたみで子項目表示
  - 子項目の「+ 項目を追加」行
  - ツリーライン表示（インデント+縦線）
- **MainView.swift**: ⚡（整理モード）の横に青い`checklist`アイコン追加 → fullScreenCoverでTodoListView表示
- **SokuMemoKunApp.swift**: ModelContainerにTodoItem.self追加

#### 設計方針
- **タグ流用**: ToDoもメモと同じTagモデルで分類（同じバッグに入る）
- **parentIDでツリー**: 無限階層対応。UIはシンプルに見えて深い階層まで掘れる
- **将来拡張フィールド**: dueDate, memo は定義済み（UIは未実装）

## 次のアクション（優先順）
1. **TodoListView の UI磨き込み**
   - 項目の削除機能（スワイプ or 長押し）
   - 項目の並び替え（ドラッグ）
   - タグ（バッグ）への紐付けUI
   - 「チェックしたら即削除」ON/OFFオプション
   - 項目タイトルのインライン編集
2. **複数リスト管理** — 「買い物リスト」「旅行荷物」など複数のToDoリストを管理する仕組み
3. **バッグ内でのToDoとメモの混在表示**
4. ボタンラボでA7（不透明ベース+色）を実機で比較検討
5. アプリアイコン

## 主要ファイル（ToDo関連）
- **TodoItem.swift**: ToDoデータモデル（parentID, isDone, tags等）
- **TodoListView.swift**: ToDo画面（ツリー表示、項目追加、チェック）

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
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **実機ビルド**: 証明書は別Macから.p12エクスポートでインポート済み、`-allowProvisioningUpdates` フラグ必要
- **ブランチ**: feature/todo-list（mainにマージ前）

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV10 + longTextTestV2
- **押せるボタンの影**: 薄い色のボタンは不透明ベース(Color(white: 0.95))を敷かないと影が透過して見えない
- **カスタムキーボード対応**: keyboardHeight はセル内で直接監視する方式（CarouselView経由ではUIHostingConfigurationの制約で伝播しない）
- **閲覧↔編集のテキスト位置揃え**: TappableReadOnlyTextのinsetsとlineFragmentPaddingをGutteredTextViewと一致させること
- **SwiftUI再帰ViewBuilder制約**: ツリー表示はフラット化して対応（todoRowの直接再帰はopaque return typeエラー）
