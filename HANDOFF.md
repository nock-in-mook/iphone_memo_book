# 引き継ぎメモ

## 現在の状況
- mainブランチで作業中
- セッション057でメモ一覧へのToDoリスト混在表示を実装

### セッション057の主な変更点

#### リスト作成ボタンのデザイン変更
- 白い線の丸囲み＋アイコン付きデザインに変更（Capsule背景→Circle stroke）
- フォントサイズ10pt、丸サイズ18pt

#### 「よく見る」フォルダを並べ替え対象に追加
- `applyTabOrder`に`frequentTabColorIndex`の分岐を追加
- 選択タブ追従にも対応

#### メモ一覧にToDoリスト混在表示
- `MemoGridItem` enum（Memo/TodoList統合型）を新設
- `TodoCardView`を作成（しおりマーク、タイトル、「ToDo ○/○件」表示）
- `filteredGridItems`でメモとToDoを統合ソート
- タップで直接TodoListViewを開く（TodoListsView経由不要）
- 長押しメニュー対応（トップ移動、固定、ロック、削除）
- 選択削除モードでもToDoリストを対象に

#### 選択モードガイド文字の強調
- 削除モード: 赤字太字16pt
- トップ移動モード: 青字太字16pt

## 次のアクション（優先順）
1. **マークダウン機能の作り込み**（次回セッションのメインタスク）
2. **タグ履歴のデバッグ**: 履歴が正しく記録・表示されるか実機確認
3. **ダミーデータ削除**: SokuMemoKunApp.swift の insertDummyTagHistory をリリース前に削除
4. **実機ビルドの問題解決**（CodeSign / Google Driveのxattr問題）
5. **フォルダ上で各メモカードに子タグバッジを表示できるか検討**
6. **並び替え問題の大改修**（ドラッグ並び替えが階層を超えて壊れる問題の根本対策）
7. **ToDoリストごとにアイコンと色を選べる機能**
8. **フォルダタブでTODOタグ選択時にTodoItemsを一覧表示**
9. **タグ（バッグ）への紐付けUI**
10. カラーブラインドモード
11. アプリアイコン

## 主要ファイル（ToDo関連）
- **TodoItem.swift**: ToDoデータモデル（listID, parentID, isDone, memo, tags等）
- **TodoList.swift**: リストモデル（id, title, isPinned, isLocked, manualSortOrder）
- **TodoListView.swift**: リスト編集画面（Listベース、連続入力、選択削除、スワイプ削除、ドラッグ並び替え、階層色帯、インラインメモ、完了バー）
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

## 主要ファイル（メモ一覧ToDo混在表示）
- **TabbedMemoListView.swift**: MemoGridItem enum、TodoCardView、filteredGridItems、todoGridItem関数

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
- **連続入力のガクつき**: Listの下端スクロールバッファ不足が原因。bottomSpacer(300pt)で解決済み
