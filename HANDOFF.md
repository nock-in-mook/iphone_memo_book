# 引き継ぎメモ

## 現在の状況
- **feature/uikit-carousel** ブランチで作業中（mainにはまだマージしていない）
- セッション046で**閲覧モードタップ位置カーソル編集**を全画面実装

### セッション046の主な変更点

#### 閲覧モードタップ→カーソル位置で編集開始（全画面対応）
- **TappableReadOnlyText**: 新規作成。非編集UITextViewでタップ位置→文字オフセットを`NSLayoutManager.characterIndex(for:in:)`で算出
- **LineNumberTextEditor**: `initialCursorOffset`パラメータ追加。初回becomeFirstResponder時にカーソル位置設定＋スクロール
- **QuickSortCellView**: TextEditor→LineNumberTextEditor化、`@FocusState`→`@State`化
- **MemoDetailView**: 閲覧テキスト→TappableReadOnlyText、`startEditing(atOffset:)`で位置指定
- **MemoInputView**: 同上
- 整理モード「本文編集ボタン」は従来通り末尾カーソル
- マークダウン表示タップは末尾カーソル（レイアウトが異なるため）

#### 閲覧↔編集テキスト位置ズレ修正
- TappableReadOnlyTextに`insets`/`lineFragmentPadding`パラメータ追加
- 閲覧モードのUITextViewインセットを編集モード（GutteredTextView）と統一
- 各画面のSwiftUIパディングも編集モードと揃えた

#### 枠外タップで編集モード解除
- MemoInputView: ヘッダータップでキーボード解除、フォーカス喪失時に閲覧モード復帰
- MemoDetailView: フッタータップでキーボード解除、フォーカス喪失時に閲覧モード復帰

#### 整理モード拡大ボタン統一
- 閲覧・編集モード共通でisExpandedで拡大制御
- isExpandedをカード高さの最優先に（ルーレット中を除く）
- タップ編集時はnormalH維持（editFromTap）、拡大ボタンで手動拡大可能
- 編集終了後もisExpanded保持

#### ROADMAP命名変更
- グラフリンク→メモリンクに変更
- リリース前タスクに「Memolette」商標・重複チェックを追加

## 次のアクション（優先順）
1. **タスクリンク / メモリンク機能**（Phase 7.5 / 8）
   - メモから子メモ・子タスクをツリー状に派生させるUI
   - メモ同士をつなぐキャンバスUI
2. ボタンラボでA7（不透明ベース+色）を実機で比較検討
3. feature/uikit-carousel → main にマージ
4. アプリアイコン

## 主要ファイル（爆速モード関連）
- **QuickSortCellView.swift**: セル（カード+ルーレットのみ、コントローラーは外）— キーボード高さ監視もここ
- **QuickSortView.swift**: メイン画面（フェーズ管理・カルーセル・コントローラーエリア・操作パネル・各種ダイアログ）
- **QuickSortFilterView.swift**: 事前フィルタ選択シート
- **ButtonLabView.swift**: アニメ塗りボタンラボ（16パターン×3色）+ PressableButtonStyle / TapPressableView定義
- **QuickSortResultView.swift**: 戦績画面
- **CarouselView.swift**: UICollectionViewベースのカルーセル
- **TagDialView.swift**: ルーレット
- **TrapezoidTabShape.swift**: 各種Shape定義
- **TappableReadOnlyText.swift**: 閲覧モード用タップ位置検出テキスト表示（NEW）
- **LineNumberTextEditor.swift**: 行番号付きエディタ（initialCursorOffset対応）

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **実機ビルド**: 証明書は別Macから.p12エクスポートでインポート済み、`-allowProvisioningUpdates` フラグ必要
- **ブランチ**: feature/uikit-carousel（mainにマージ前）

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV10 + longTextTestV2
- **押せるボタンの影**: 薄い色のボタンは不透明ベース(Color(white: 0.95))を敷かないと影が透過して見えない
- **カスタムキーボード対応**: keyboardHeight はセル内で直接監視する方式（CarouselView経由ではUIHostingConfigurationの制約で伝播しない）
- **閲覧↔編集のテキスト位置揃え**: TappableReadOnlyTextのinsetsとlineFragmentPaddingをGutteredTextViewと一致させること
