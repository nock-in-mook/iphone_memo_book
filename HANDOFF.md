# 引き継ぎメモ

## 現在の状況
- **feature/roulette-size-test** ブランチで作業中（mainからの分岐）
- ルーレットのサイズ拡大・カラー切替・トレーUI改善を実施

### 今回の変更点（セッション022）
- トレー背景チラ見せ（bodyPeek: 閉じ時にボディが取っ手内に10pt侵入）
- 取っ手を70→50ptに短縮、テキスト「タグ付け」→「タグ」
- トレー色をColor.grayに統一（子タグドロワーと同じ）
- ルーレットクリップ境界にインナーシャドウ追加（Canvas内描画）
- トレー外タップで収納機能追加
- 開き時のルーレット位置調整（offset -30→-27、閉じ時との違和感解消）
- TrayWithTabShapeにbodyPeekパラメータ追加
- トレー全体の位置を右に5ptずらし（trailing -10→-15）

## 備忘
- **子タグドロワー維持**: 他のフォルダに移っても子タグドロワーは閉じないようにする（現状は閉じてしまう？要確認）

## ブランチ構成
- **main**: セッション020までの全機能統合済み + トレー方式基本実装
- **feature/roulette-size-test**: サイズ拡大テスト + トレーUI改善（mainにマージ検討中）

## 主要ファイル
- MemoInputView.swift: トレー方式（TrayWithTabShape一体型、offset開閉、peekAmount、bodyPeek）
- TagDialView.swift: 白板+カラー切替、傾きバッジ、ゴムバンド、可変フォント、インナーシャドウ
- ROADMAP.md: 左利き対応、行番号表示、文字サイズ変更追記

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro Max (95C8A8C5-0972-4BB0-B793-5219096697DF) ← iOS 17.2
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. **子タグに関する備忘を確認**（ユーザーに聞く）
2. **feature/roulette-size-testをmainにマージするか判断**
3. **チラ見せ量の調整**（peekAmount を微調整）
4. **ポインター（赤い三角）の見た目改善**
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
