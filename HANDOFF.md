# 引き継ぎメモ

## 現在の状況
- **feature/uikit-carousel** ブランチで作業中（mainにはまだマージしていない）
- セッション040で**セル内包方式の大工事**を実施完了

### セッション040の主な変更点

#### セル内包方式（大工事）
- **QuickSortCellView.swift 新規作成**: カード + サジェスト + ルーレットを1つのUICollectionViewセルに統合
- 各セルが独立した`@State`でタグ管理（`selectedParentTagID`, `selectedChildTagID`等）
- 親ビュー（QuickSortView）の共有Stateを大幅削除 → カード切替時の再描画ゼロ
- **CarouselView**: `spacing: 0`のフルページ方式に変更（セル幅=画面幅）
- **QuickSortView**: 512行追加 / 589行削除の大幅リファクタ
  - 削除: `syncEditingState`, `applyTagFromDial`, `suggestPanel`, `dialArea`, `cardItem`, `tagBadge`, `arrowGuide`等
  - セルへの移管: タグ操作、サジェスト表示、ルーレット表示、削除ジェスチャー
  - 新規タグ作成: セルからコールバック → 親がsheet表示 → memo.tagsに直接書き込み → セルのonChange検知

### 前セッション039の変更点（参考）
- UICollectionViewベースのカルーセル置き換え
- CardWithTabShape（タブ+カード一体パス描画）
- 上下入れ替え（サジェスト+ルーレット上、カード下）
- 削除を下スワイプに変更

## 次のアクション（優先順）
1. **シミュレータで動作確認** — セル内包方式が正しく動くか検証
2. **UIの微調整** — セル内のサジェスト+ルーレット配置、余白調整
3. **ルーレットの横スクロール干渉チェック** — セル内ルーレットの縦ドラッグとカルーセルの横スクロールが共存するか確認
4. **feature/uikit-carousel → main にマージ**
5. 実機テストでパフォーマンス確認
6. アプリアイコン
7. 編集時/閲覧時の文字サイズ変更

## 主要ファイル（爆速モード関連）
- **QuickSortView.swift**: メイン画面（フェーズ管理・カルーセル・編集オーバーレイ・セット管理）
- **QuickSortCellView.swift**: セル内包ビュー（カード+サジェスト+ルーレット統合）★NEW
- **CarouselView.swift**: UICollectionViewベースのカルーセル（フルページ方式）
- **QuickSortFilterView.swift**: フィルタ選択
- **QuickSortResultView.swift**: 戦績表示
- **TrapezoidTabShape.swift**: TrapezoidTabShape, CardTitleTabShape, CardWithTabShape, Triangle の定義
- **TagDialView.swift**: ルーレット（@Bindingのまま、セルから渡されるローカルStateをバインド）
- **MainView.swift**: ⚡ボタン→fullScreenCover起動

## 環境
- **Mac②（新）**: MacBook Air — Xcode 26.3, シミュレータ iPhone 17 Pro (iOS 26.3.1)
- 実機: 15promax (26.3.1) — デバイスID: 00008130-0006252E2E40001C
- **ブランチ**: feature/uikit-carousel（mainにマージ前）

## 注意点
- DerivedData キャッシュ → `rm -rf ~/Library/Developer/Xcode/DerivedData/SokuMemoKun-*`
- **ビルドキャッシュが頑固**: DerivedData削除+アンインストール+clean+フルリビルドが確実
- SourceKitの偽陽性エラー多発→ビルドは成功する
- **バンドルID**: com.sokumemokun.app
- **テストデータバージョン**: sampleDataV10
- **MainViewのhueFromColorIndex内RGBテーブル**: tabColorsと同じ値を維持すること
- **pbxprojのカスタムID**: CAROUSEL00000000000001/2, CELLVIEW00000000000001/2
