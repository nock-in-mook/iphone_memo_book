import SwiftUI
import UIKit

// UICollectionViewベースのカルーセル（スナップ・高速スクロール対応）
struct CarouselView: UIViewControllerRepresentable {
    let items: [Memo]
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    @Binding var currentMemoID: UUID?
    let isScrollDisabled: Bool
    // カード描画用のクロージャ（AnyViewで型消去）
    let cardContent: (Memo) -> AnyView

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let coord = context.coordinator
        let vc = UIViewController()
        vc.view.backgroundColor = .clear

        // コレクションビュー作成
        let layout = makeLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.delegate = coord
        cv.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: vc.view.topAnchor),
            cv.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
            cv.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
        ])
        coord.collectionView = cv

        // セル登録 + データソース
        let registration = UICollectionView.CellRegistration<UICollectionViewCell, UUID> { cell, indexPath, memoID in
            guard let memo = coord.parent.items.first(where: { $0.id == memoID }) else { return }
            cell.contentConfiguration = UIHostingConfiguration {
                coord.parent.cardContent(memo)
            }
            .margins(.all, 0)
            cell.backgroundColor = .clear
        }

        let ds = UICollectionViewDiffableDataSource<Int, UUID>(collectionView: cv) { cv, indexPath, memoID in
            cv.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: memoID)
        }
        coord.dataSource = ds

        // 初期データ
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(items.map { $0.id })
        ds.apply(snapshot, animatingDifferences: false)

        // 初期スクロール位置
        if let id = currentMemoID, let index = items.firstIndex(where: { $0.id == id }) {
            DispatchQueue.main.async {
                cv.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: false)
            }
        }

        return vc
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        let coord = context.coordinator
        coord.parent = self

        guard let cv = coord.collectionView else { return }

        // スクロール有効/無効
        cv.isScrollEnabled = !isScrollDisabled

        // アイテム更新
        let currentIDs = items.map { $0.id }
        if currentIDs != coord.lastItemIDs {
            coord.lastItemIDs = currentIDs
            var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
            snapshot.appendSections([0])
            snapshot.appendItems(currentIDs)
            coord.dataSource?.apply(snapshot, animatingDifferences: true)
        }

        // 外部からのスクロール指示（Bindingが変わった時）
        if let targetID = currentMemoID,
           targetID != coord.lastReportedID,
           !coord.isUserScrolling,
           let index = items.firstIndex(where: { $0.id == targetID }) {
            coord.lastReportedID = targetID
            cv.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
        }

        // レイアウト更新（サイズ変更時）
        if coord.lastCardWidth != cardWidth || coord.lastCardHeight != cardHeight {
            coord.lastCardWidth = cardWidth
            coord.lastCardHeight = cardHeight
            cv.collectionViewLayout = makeLayout()
        }
    }

    // 水平ページングレイアウト
    private func makeLayout() -> UICollectionViewFlowLayout {
        let layout = SnapCenterFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: cardWidth, height: cardHeight)
        layout.minimumLineSpacing = 12
        return layout
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        var parent: CarouselView
        weak var collectionView: UICollectionView?
        var dataSource: UICollectionViewDiffableDataSource<Int, UUID>?
        var lastReportedID: UUID?
        var lastItemIDs: [UUID] = []
        var isUserScrolling = false
        var lastCardWidth: CGFloat = 0
        var lastCardHeight: CGFloat = 0

        init(parent: CarouselView) {
            self.parent = parent
        }

        // 左右の余白（カードを中央配置するため）
        func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            let side = (collectionView.bounds.width - parent.cardWidth) / 2
            return UIEdgeInsets(top: 0, left: side, bottom: 0, right: side)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserScrolling = true
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isUserScrolling = false
            reportCenterItem()
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                isUserScrolling = false
                reportCenterItem()
            }
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            reportCenterItem()
        }

        private func reportCenterItem() {
            guard let cv = collectionView else { return }
            let center = CGPoint(
                x: cv.contentOffset.x + cv.bounds.width / 2,
                y: cv.bounds.height / 2
            )
            if let indexPath = cv.indexPathForItem(at: center),
               indexPath.item < parent.items.count {
                let memoID = parent.items[indexPath.item].id
                if memoID != lastReportedID {
                    lastReportedID = memoID
                    DispatchQueue.main.async {
                        self.parent.currentMemoID = memoID
                    }
                }
            }
        }
    }
}

// 中央スナップ付きFlowLayout
class SnapCenterFlowLayout: UICollectionViewFlowLayout {
    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let cv = collectionView else { return proposedContentOffset }

        let cvCenter = proposedContentOffset.x + cv.bounds.width / 2
        let attrs = layoutAttributesForElements(in: CGRect(
            x: proposedContentOffset.x,
            y: 0,
            width: cv.bounds.width,
            height: cv.bounds.height
        )) ?? []

        var closest: UICollectionViewLayoutAttributes?
        var minDist = CGFloat.greatestFiniteMagnitude

        for attr in attrs {
            let dist = abs(attr.center.x - cvCenter)
            if dist < minDist {
                minDist = dist
                closest = attr
            }
        }

        guard let target = closest else { return proposedContentOffset }
        return CGPoint(x: target.center.x - cv.bounds.width / 2, y: proposedContentOffset.y)
    }
}
