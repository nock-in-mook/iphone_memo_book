# 引き継ぎメモ

## 現在の状況
- **feature/uikit-carousel** ブランチで作業中（mainにはまだマージしていない）
- セッション043で**爆速メモ整理モードのUI大改修第2弾**を実施

### セッション043の主な変更点

#### フィルター画面（QuickSortFilterView）
- 名称変更: 「爆速振り分けモード」→「爆速メモ整理モード」
- ヘッダー順序変更（タイトル上、稲妻マーク下）
- 説明文追加（箇条書き + 緑チェックボックス付き）
- 「複数選択可」青字テキスト追加
- 「特定のタグのメモ」: 未選択時は件数非表示 + 下向き矢印、展開だけではチェック入らずタグ選択でチェック

#### ダミーローディング画面復活
- doc.on.doc.fillアイコン（緑、-30度傾き）+ グラデーションプログレスバー
- 10件以下: 1.5秒、11件以上: 3秒

#### コントローラーエリア（ゲームパッド風UI）
- **弧型仕切り線**（ArcDivider）: 端から端まで、高さ70pt
- **3つの押せるボタン**（TapPressableView）: 弧に沿って配置
  - タイトル編集（オレンジ系、左、-13度傾き）
  - 本文編集（グレー系、中央）
  - タグ編集（シアン系、右、13度傾き）
- **ArcCapsule**: カスタムShape（上下辺が弧を描くカプセル型、仕切り線と同じ曲率）
- **PressableButtonStyle / TapPressableView**: タップで沈む→戻る物理ボタン風アニメーション
- ボタンの不透明ベース + 色グラデ重ねで影を確保
- 各ボタンはトグル動作（編集中に再押しで抜ける、別ボタンなら切替）

#### 本文インライン編集
- カード内でTextEditorに切り替わりその場で編集
- 編集中はカードが55%に拡大（アニメーション付き）
- 枠外タップで編集終了（タイトル・本文両方）
- ページ切替時も確実に保存

#### ボタンデザインラボ（ButtonLabView）
- 設定画面に追加（30種静的パターン + 12種押せるボタン）
- PressableButtonStyle: 影が減ってゼロになる押した感

#### テキストスタイルラボ（TextStyleLabView）
- 24パターンのテキスト装飾（ドロップシャドウ、エンボス、グロス等）
- 3色ボタンセットで並列表示

#### ROADMAP追記
- Phase 7.5: タスクリンク機能
- テキスト編集時のトップ/ボトム戻りボタン
- ToDoモード独自記法

#### Tips
- `_Apps2026/Tips/押せるボタン実装メモ.md` 作成・更新

## 次のアクション（優先順）
1. **爆速モードUIブラッシュアップ続行**（ボタン微調整、弧テキスト再挑戦等）
2. ルーレット回転演出の設計
3. feature/uikit-carousel → main にマージ
4. 実機テストでパフォーマンス確認
5. アプリアイコン

## 主要ファイル（爆速モード関連）
- **QuickSortCellView.swift**: セル内包ビュー（カード+コントローラーエリア+ルーレット統合）
- **QuickSortFilterView.swift**: 事前フィルタ選択シート
- **QuickSortView.swift**: メイン画面（フェーズ管理・カルーセル・編集オーバーレイ）
- **ButtonLabView.swift**: ボタンデザインラボ（PressableButtonStyle / TapPressableView定義もここ）
- **TextStyleLabView.swift**: テキストスタイルラボ
- **CarouselView.swift**: UICollectionViewベースのカルーセル
- **TagDialView.swift**: ルーレット
- **TrapezoidTabShape.swift**: 各種Shape定義

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
- **押せるボタンの影**: 薄い色のボタンは不透明ベース(Color(white: 0.95))を敷かないと影が透過して見えない
