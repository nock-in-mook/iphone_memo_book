# 引き継ぎメモ

## 現在の状況
- **feature/roulette-size-test** ブランチで作業中（mainからの分岐）
- ルーレットのサイズ拡大・カラー切替・UI大幅改善を実施

### 今回の変更点（セッション021）
- ルーレットをトレー方式に構造変更（TrayWithTabShapeで取っ手+トレー一体型）
- 常時描画+offset方式でチラ見せ対応準備完了（peekAmount変数あり）
- 白板+カラーバッジ方式→開閉でセクター色を切替（閉じ=白、開き=タグカラー塗りつぶし）
- 閉じてる時は全スロットに仕切り線（骨格表示）、開いてる時はタグありのみ
- バッジ背景を完全削除（セクター塗り+テキストのみ）
- タグバッジ+テキストがルーレット回転に合わせて傾く
- 無限ループ廃止、端でゴムバンド跳ね返り（1タグでも動作）
- 親タグの並び順をsortOrderに統一（フォルダタブと同じ）
- 子ルーレット常時表示、トグルボタン廃止
- セクター幅82→110pt、半径270→350、角度8度
- クリップ範囲を211ptに拡大
- フォントサイズを文字数+親子で可変（親:最大24pt、子:最大16pt）
- 文字数制限を緩和（親10文字、子7文字）
- 「タグなし」「なし」を薄グレー固定フォントに
- テキスト色を背景色の明るさで自動判定
- 円弧フレームの描画範囲をパネル端まで拡大
- ROADMAPに追記（行番号表示、文字サイズ変更、左利き対応）

## ブランチ構成
- **main**: セッション020までの全機能統合済み + トレー方式基本実装
- **feature/roulette-size-test**: サイズ拡大テスト（mainにマージ検討中）

## 主要ファイル
- MemoInputView.swift: トレー方式（TrayWithTabShape一体型、offset開閉、peekAmount）
- TagDialView.swift: 白板+カラー切替、傾きバッジ、ゴムバンド、可変フォント
- ROADMAP.md: 左利き対応、行番号表示、文字サイズ変更追記

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. **feature/roulette-size-testをmainにマージするか判断**
2. **チラ見せ量の調整**（peekAmount を 0 以外に設定してテスト）
3. **ポインター（赤い三角）の見た目改善**
4. **追加ボタンの配置調整**
5. Specialメニュー実装（30ptスペースからの引き出し）
6. マークダウン編集リニューアル
7. 実機ビルド・テスト

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **実機ビルドキャッシュ問題**: DerivedDataクリーンでも実機に古いビルドが残ることがある。`xcodebuild clean` + フルリビルドが確実
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **子タグ連打フリーズ**: withAnimationの競合が原因。子タグタップのwithAnimationを除去、.animation(.spring)のスコープをドロワーのみに限定して解決
- **グリッドカード高さ**: 動的計算(cardHeight)が効かないためハードコード
- **MemoInputView.onConfirm**: 確定処理はMainView.confirmMemo()に集約。hasDiffで差分検出
- **バンドルID**: com.sokumemokun.app
