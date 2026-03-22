# 引き継ぎメモ

## 現在の状況
- **feature/uikit-carousel** ブランチで作業中（mainにはまだマージしていない）
- セッション045で**カスタムキーボード高さ対応・UI微調整**を実施

### セッション045の主な変更点

#### カスタムキーボード高さ対応（重要）
- 問題: サードパーティ製キーボード（デフォルトより高い）使用時、カーソル行がキーボードに隠れていた
- 原因: UICollectionView（CarouselView）経由で渡す `keyboardHeight` がセル内のSwiftUIビューに伝播しなかった（UIHostingConfigurationの制約）
- 解決: QuickSortCellView内で直接 `keyboardWillChangeFrameNotification` を購読し、`@State` でキーボード高さを管理
- `keyboardWillShowNotification` → `keyboardWillChangeFrameNotification` に変更（キーボード種類切替時も検知）
- キーボード高さは `screenHeight - frame.origin.y` で算出（スクリーン座標ベース）

#### UI微調整
- 編集ボタン3つを10pt上に移動（offset -40 → -50）
- ロックボタンの視認性改善（不透明度0.4→0.7、背景0.08→0.15、枠線0.15→0.3）

### 既知の課題
- カスタムキーボード切替時にカードがカクッと動く（`keyboardWillChangeFrameNotification` が中間フレームも通知するため）→ 許容範囲

## 次のアクション（優先順）
1. **閲覧中の本文タップでカーソル位置編集開始**（Google Keep風 — タップ位置にカーソルが飛ぶ）
   - UITextViewラップが必要（SwiftUI TextEditorではタップ位置のカーソル制御が困難）
   - 本文編集ボタン経由の場合は末尾カーソルでOK
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

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro (iOS 26.3.1)
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
