# 引き継ぎメモ

## 現在の状況
- mainブランチで作業中
- セッション059でMDトグルUI・アイコン統一・各種バグ修正を実施
- **Flutter移行を決定** — 次セッションでFlutter環境構築から開始

### セッション059の主な変更点

#### MDトグル初回説明ダイアログ
- 初めてMDボタンをタップした時にリッチダイアログで説明表示
- 「非表示にする」「残しておく」の選択肢付き
- MDモードON/OFF時に「マークダウンモード オン/オフ」トースト表示

#### MDトグルUI改善
- 「MD」テキスト（14pt）+ ミニトグルスイッチ（青色）に変更
- ゴミ箱との間にスペース追加
- 設定テキスト: 「マークダウン切替ボタンを常時表示」「常にマークダウンモードON」

#### MDアイコン自動判定
- memo.isMarkdownフラグ依存 → containsMarkdown()によるテキスト内容自動判定に変更
- 正規表現で見出し・リスト・太字・引用・リンク等を検出（先頭500文字）
- カードのMDマークを紫背景+白文字バッジに統一（全画面）

#### アイコン統一・並び順
- 全カードで ピン→MD→ロック の並び順に統一
- 爆速モードのロックアイコン: 丸枠+縁取り線
- メモ一覧のロックアイコン: シンプル（枠なし）
- 爆速モードの右上アイコンをHStackで統一配置

#### フッターレイアウト改善
- 左グループ（削除+MDトグル）と右グループ（Undo/Redo+コピー+確定/閉じる）に分離
- 右端ボタンの途切れ解消
- アイコンとテキストのHStack spacing 3ptに

#### KeyboardDismissView修正
- windowへのジェスチャー追加をやめ、view自身にジェスチャー追加
- キーボード非表示時はタッチを完全透過（ボタンタップ阻害を解消）

#### 確定ボタンの動作統一
- 確定ボタンは常にキーボード閉じるだけ（保存・クリア廃止）
- タイトル編集中も「確定」を正しく表示（isTitleEditing @Stateで追跡）
- キーボード表示中のみ「確定」、既存メモ非編集時「メモを閉じる」
- タイトルのみ入力時も「メモを閉じる」表示

#### 爆速モード改善
- メモ順をフォルダ一覧と統一（ピン固定→手動順→作成日降順）
- カード下に最終更新日・作成日を表示（入力中/ルーレット/最大化時は非表示）
- ピンマーク追加
- フィルタ画面のチェックアニメーションOFF
- 最大化時のカード高さ 80%→77%

## 次のアクション（最優先）
1. **Flutter版プロジェクト作成**（別プロジェクトフォルダ: `_Apps2026/MemoletteFl` 等）
2. **Flutter環境構築**（Flutter SDK, Android Studio, CocoaPods, flutter doctor）
3. **Swift版の機能をFlutter版に移植開始**（コア機能から）

## Flutter移行の方針
- Swift版は `_Apps2026/Memolette` にそのまま残す（戻れるように）
- Flutter版は別プロジェクトフォルダで管理
- 同期はFirebaseベースで設計（全プラットフォーム対応）
- 画像挿入は圧縮+リサイズ方式（長辺1024px, JPEG 70%, 1枚100-200KB）
- 必要に応じてiCloud同期も後から追加可能

## 主要ファイル（マークダウン関連）
- **LineNumberTextEditor.swift**: GutteredTextViewにMDスタイリング統合済み
- **MarkdownToolbar.swift**: キーボード直上の記号入力バー
- **MarkdownPreviewView.swift**: プレビュー表示（全記法対応）
- **MemoInputView.swift**: MDトグル・プレビューボタン・TextAreaLayout定数

## 主要ファイル（定数管理）
- **Constants/AppStorageKeys.swift**: UserDefaultsキー文字列の一元管理
- **Constants/DesignConstants.swift**: CornerRadius/Shadow/TagBorder定数

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro (iOS 26.3)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **ビルド**: Google Drive上のファイル変更検知問題あり。xattr -cr . が必要

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ダイアログルール**: 全てカスタムリッチダイアログ（標準alertは使わない）
- **TextKit 1**: GutteredTextViewはUITextView(usingTextLayoutManager: false)を使用
- **lineFragmentPadding**: 0に設定済み（余白最小化）
- **シミュレータでprintデバッグは使えない**: UI overlay等で対応
