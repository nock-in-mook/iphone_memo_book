# 引き継ぎメモ

## 現在の状況
- **feature/roulette-size-test** ブランチで作業中（mainからの分岐）
- トレー2段階収納、タグサジェスト辞書追加、ルーレットUI改善を実施

### 今回の変更点（セッション023）
- トレー2段階収納機能（チラ見せ→完全収納、タップで全開）
- 取っ手テキスト「タグ」→「タグ付け」に変更、tabWidth 80pt
- 完全収納時の覗き量34pt、取っ手が少しだけ顔を出す
- 設定画面にタグトレー起動時状態（チラ見せ/全開/隠す）追加
- TrayWithTabShapeに内側角カーブ（innerRadius: 10pt）追加
- ルーレット外周線を3ptに変更、色は元のグラデーションに戻した
- ルーレット展開時に「親タグ」「子タグ」ラベルを取っ手帯に表示（trailing 200/83で固定）
- 追加ボタンをZStack独立配置、フォント調整（親14pt/子13pt）
- Canvas余白14ptに拡大（外周線クリップ対策）
- タグサジェスト辞書（TagSuggestDictionary.json）4449語・141タグ追加
- ROADMAP: タグサジェスト3層構造、学習機能、長押し編集追記

## 備忘
- **子タグドロワー維持**: 他のフォルダに移っても子タグドロワーは閉じないようにする（要確認）
- **ルーレットのタグパネル長押しで編集・削除**: ROADMAPに追記済み

## ブランチ構成
- **main**: セッション020までの全機能統合済み + トレー方式基本実装
- **feature/roulette-size-test**: サイズ拡大テスト + トレーUI改善（mainにマージ検討中）

## 主要ファイル
- MemoInputView.swift: トレー方式（2段階収納、TrayWithTabShape内側カーブ、親子ラベル、追加ボタンZStack配置）
- TagDialView.swift: 白板+カラー切替、傾きバッジ、ゴムバンド、可変フォント、外周線3pt
- SettingsView.swift: タグトレー起動時状態設定追加
- TagSuggestDictionary.json: タグサジェスト事前辞書（4449語）
- ROADMAP.md: タグサジェスト3層構造、学習機能、長押し編集

## 環境
- **Mac①（旧）**: MacBook Air M2 — Xcode旧版, シミュレータ iPhone 15 Pro Max (iOS 17.2)
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro Max (iOS 26.3.1)
- 実機: 15promax (26.3.1) (00008130-0006252E2E40001C)
- 2台体制でiOS 17 / iOS 26 両方の互換性テストが可能
- ビルド後は毎回「Fit Screen」でウィンドウ縮小する

## 次のアクション
1. **タグサジェスト機能のUI実装**（表示場所を決めて組み込む）
2. **ユーザーデータ学習機能**（TagFrequencyモデル作成、保存時に蓄積）
3. **ルーレット長押しでタグ編集・削除**
4. **feature/roulette-size-testをmainにマージするか判断**
5. Specialメニュー実装（30ptスペースからの引き出し）
6. マークダウン編集リニューアル
7. 実機ビルド・テスト

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- **実機ビルドキャッシュ問題**: DerivedDataクリーンでも実機に古いビルドが残ることがある
- SwiftUIのButton内テキストが青くなる → `.buttonStyle(.plain)`
- MemoInputViewModelは@Stateで一度だけ生成 → 設定変更はonChangeで反映
- ModelContainerは共有必須
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **子タグ連打フリーズ**: withAnimationの競合が原因。解決済み
- **バンドルID**: com.sokumemokun.app
