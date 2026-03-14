# 引き継ぎメモ

## 現在の状況
- feature/input-area-expand-and-view-mode ブランチで作業中
- 入力欄の展開/縮小機能を実装（全画面エディタ廃止→入力欄が下に伸びる方式）
- ルーレット（タグダイアル）の位置を割合ベースで固定（展開しても位置不変）
- タグタブを枠線の外（画面右端）から生やす方式に変更
- タグタブはドラッグでのみ開く（タップ誤操作防止）
- タブインデックスをsortOrderベースに修正（ルーレット↔タブの同期修正）
- 「タグなし」選択時のタブ遷移バグ修正
- 閲覧/編集モード切替（既存メモは閲覧モードで開く）
- テキスト位置をTextEditor/Text間で揃え済み

## 主要ファイル
- MemoInputView.swift: 展開/縮小、ルーレット位置固定、タグタブ枠外配置、ドラッグオンリータブ
- MemoInputViewModel.swift: loadMemoCounter（閲覧モード切替トリガー）
- MainView.swift: isInputExpanded状態管理、高さ0.48/0.92切替
- FullEditorView.swift: 空（EmptyView）— 互換用に残存
- TabbedMemoListView.swift: グリッド5段階、選択削除右下配置
- TagDialView.swift: Canvas描画ルーレット
- MarkdownTextEditor.swift: Bear風インラインマークダウンエディタ

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. featureブランチをmainにマージ
2. 実機ビルド・テスト（iPhone 15 Pro Max実機、署名設定が必要）
3. ヘッダーのタグ表示タップ（ルーレット展開）もドラッグオンリーにするか検討
4. FullEditorView.swift / MemoDetailView.swiftの不要コード整理
5. 設定で「子タグルーレットを常に表示」のオンオフ切替
6. マークダウン編集画面のテコ入れ
7. 横画面対応、iPad対応レイアウト、アプリアイコン

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発（tagColor, UIPasteboard, UIResponder等）→ビルドは成功する
- NotificationCenter(.switchToTab)でルーレット↔タブ間のクロスビュー通信
- タブインデックスはsortOrderベース（name sortではない）
- タグタブのoverlayはpadding前に配置（枠外に伸ばすため）
