# 引き継ぎメモ

## 現在の状況
- Phase 1 実装完了、UI改善中
- TagDialView（カジノルーレット風タグ選択）の弧の向きが正しくなった
- 中心アイテムが最も左に突出、上下のアイテムが右にカーブする弧を実現
- 台形タブUI、紙テクスチャ背景、4列グリッドレイアウト実装済み
- タイトル入力欄をメイン画面に統合、保存後シート廃止

## 今回の修正内容
- TagDialView: GeometryReader → ZStack + offset ベースに変更
- 弧の座標計算: `arcX = wheelRadius * (1 - cos(rad))` で正しい方向の弧を実現
- フレームを72pt幅 × 160pt高に固定してクリッピング
- wheelRadius=300, itemAngle=8 で緩やかな弧
- DerivedDataキャッシュ問題の発見・解決（クリーンビルドが必要だった）

## 環境
- Mac: MacBook Air M2, macOS
- Xcode: 26.3
- シミュレータ: iPhone 15 Pro (3827F785-169E-4B8F-AF2E-C0E57438C523) ← iOS 17.2
- iPhone 17 (88CF5AD1) も使用可能だが iOS 26.3.1
- ビルドコマンド: `xcodebuild -project SokuMemoKun/SokuMemoKun.xcodeproj -scheme SokuMemoKun -destination 'platform=iOS Simulator,id=3827F785-169E-4B8F-AF2E-C0E57438C523' build`

## 次のアクション
1. ルーレットの微調整（サイズ、スワイプ感度、フォント等）
2. ルーレットの選択状態の視覚フィードバック改善
3. 全体的なUI polish
4. Phase 2: iCloud/CloudKit設定・同期テスト
5. 実機テスト

## 注意点
- DerivedData キャッシュが原因でビルドが反映されないことがある → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*` でクリーンビルド
- DEVELOPMENT_TEAM は空欄 → 実機テスト時にXcodeでApple IDチーム設定が必要
- iPhone 17 Pro Max (021FC865) が Booted 状態のまま残っている可能性あり
