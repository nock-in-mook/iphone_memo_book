# 引き継ぎメモ

## 現在の状況
- **remove-tag-suggest** ブランチで作業中（mainにはまだマージしていない）
- セッション053で爆速モードUI刷新、タグサジェスト削除、タグ履歴機能追加を実施

### セッション053の主な変更点

#### 爆速モード — ルーレットをトレー方式に統一
- MemoInputViewと同じトレー背景(TrayWithTabShape)を爆速モードに移植
- チラ見せ状態を廃止、完全表示/完全非表示の二択に
- ページ送り時にタグモードを維持（連続タグ付け可能に）
- 最大化ボタンでルーレットを閉じて本文最大化
- ルーレット表示中の編集モード切替でルーレットを維持
- タグ編集ボタンでルーレット出し入れ（トグル）

#### 爆速モード — 操作パネルUI刷新
- 編集ボタン3つをマット塗りスタイルに変更（アイコン+テキスト）
- 前へ/次へを青い三角形マット塗りボタンに
- ゴミ箱を丸型マット塗りボタンに（赤アイコン）
- 全ボタンの影スタイルを統一(shadowHeight:4, black 0.15)
- TapPressableViewにcompositingGroup追加(テキスト影を独立制御)
- ボタンに不透明背景+グレー縁取り追加(仕切り線の透け防止)

#### 爆速モード — その他改善
- 削除後に同じ位置のメモに移動（1枚目に戻らないバグ修正）
- 結果画面→削除確認シートのチラ見え防止
- 削除行に「確認」リンク追加、「← 左スワイプで復元」説明
- メモカードに「タイトルなし」「タグなし」バッジ（操作中は非表示、アニメーション後表示）
- ダイアログ文言修正（「整理を終了」「保存せず終了」「結果表示画面で復元できます」）

#### タグサジェスト機能 → 完全削除
- TagSuggestEngine, TagFrequency, TagCooccurrence, TagSuggestDismissal, TagSuggestDictionary.json を全削除
- MainView, MemoInputViewModel, NewTagSheetView, SokuMemoKunApp からサジェスト関連コード除去

#### タグ履歴機能 — 新規追加
- TagHistoryモデル（親+子の組み合わせを記録、最大20件、重複は日時更新）
- ルーレット閉じた時・ページ送り時に記録
- 普段の入力画面: トレー外に「▷ 履歴」ボタン、MainViewで白いフローティングウィンドウ表示
- 爆速モード: トレー外に「▷ 履歴」ボタン、カード中央にoverlay表示
- スクロール矢印付き、xボタン・タグ変更・テキスト入力等で自動閉じ
- ダミー履歴データ20件追加（デバッグ用・リリース前に削除要）

#### フォルダタブ・入力画面
- タブテキストの影をシャープに(radius 0.5, opacity 0.2, 距離0.5)
- メモ入力プレースホルダーの左パディングをカーソル位置に合わせた(18→21pt)

## 次のアクション（優先順）
1. **remove-tag-suggest ブランチをmainにマージ**
2. **タグ履歴のデバッグ**: 履歴が正しく記録・表示されるか実機確認
3. **ダミーデータ削除**: SokuMemoKunApp.swift の insertDummyTagHistory をリリース前に削除
4. **実機ビルドの問題解決**（CodeSign / Google Driveのxattr問題）
5. **並び替え問題の大改修**（ドラッグ並び替えが階層を超えて壊れる問題の根本対策）
6. **ToDoリストごとにアイコンと色を選べる機能**
7. **フォルダタブでTODOタグ選択時にTodoItemsを一覧表示**
8. **タグ（バッグ）への紐付けUI**
9. カラーブラインドモード
10. アプリアイコン

## 主要ファイル（ToDo関連）
- **TodoItem.swift**: ToDoデータモデル（listID, parentID, isDone, memo, tags等）
- **TodoList.swift**: リストモデル（id, title, isPinned, isLocked, manualSortOrder）
- **TodoListView.swift**: リスト編集画面（Listベース、スワイプ削除、ドラッグ並び替え、階層色帯、インラインメモ）
- **TodoListsView.swift**: リスト一覧画面（2列Pinterest風、プレビュー付きカード、長押しメニュー）

## 主要ファイル（爆速モード関連）
- **QuickSortCellView.swift**: セル（カード+ルーレットのみ、コントローラーは外）— キーボード高さ監視・タグ履歴・バッジ表示もここ
- **QuickSortView.swift**: メイン画面（フェーズ管理・カルーセル・コントローラーエリア・操作パネル・各種ダイアログ）
- **QuickSortFilterView.swift**: 事前フィルタ選択シート
- **QuickSortResultView.swift**: 結果表示画面（削除確認リンク付き）
- **CarouselView.swift**: UICollectionViewベースのカルーセル
- **TagDialView.swift**: ルーレット
- **MemoInputView.swift**: メモ入力画面（トレー方式ルーレット・タグ履歴ボタン）
- **LineNumberTextEditor.swift**: 行番号付きエディタ（isEditable/onTapWhileReadOnly対応）

## 主要ファイル（タグ履歴関連）
- **TagHistory.swift**: タグ使用履歴モデル（record/recentHistory）
- **MainView.swift**: tagHistoryListView（フォルダタブゾーンにoverlay表示）
- **MemoInputView.swift**: 履歴ボタン（トレー外overlay）、履歴記録（ルーレット閉じ時）
- **QuickSortCellView.swift**: 履歴ボタン（トレーoverlay）、履歴リスト（カード中央overlay）、履歴記録（ページ送り時・タグ編集閉じ時）

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro (iOS 26.3)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **実機ビルド**: Wi-Fi経由で接続可能（同じWiFi上なら）、`-allowProvisioningUpdates` フラグ必要
- **ビルド**: Google Drive上のファイル変更検知問題あり。ローカルコピーしてビルドが確実:
  ```
  rm -rf /tmp/SokuMemoKun-src /tmp/SokuMemoKun-DD && cp -R "...SokuMemoKun" /tmp/SokuMemoKun-src && cd /tmp/SokuMemoKun-src && xattr -cr . && xcodebuild ...
  ```

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **ダイアログルール**: 全てカスタムリッチダイアログ（標準alertは使わない）
- **SwiftUI再帰ViewBuilder制約**: ツリー表示はフラット化して対応
- **キーボードとダイアログ**: ダイアログはNavigationStack外のZStackに配置（押し潰れ防止）
- **LazyVStack + DragGesture は使わない**: ScrollViewのスクロールが死ぬ。Listを使うこと
- **チェックボックス**: Image+onTapGestureで28x28に限定（Buttonだとタップ判定が広がる）
- **Google Drive上のxattr問題**: ビルド前に`xattr -cr .`が必要（resource fork等のデトリタス）
