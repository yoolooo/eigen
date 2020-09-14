import UIKit


class AuctionBuyNowView: ORStackView {
    var embeddedVC: AREmbeddedModelsViewController?
    var actionDelegate: UIViewController?

    var saleArtworks: [SaleArtwork]?
    var isCompact = true

    func setup(isCompact: Bool, promotedSaleArtworks: [SaleArtwork], viewController: UIViewController, delegate: UIViewController) {

        let titleView = AuctionBuyNowTitleView(isCompact: isCompact)
        addSubview(titleView, withTopMargin: "0", sideMargin:"0")

        let layout = isCompact ? ARArtworkMasonryLayout.layout2Column : ARArtworkMasonryLayout.layout3Column

        let module = ARArtworkMasonryModule(layout: layout, andStyle: .artworkMetadata)
        let buyNowWorksVC = AREmbeddedModelsViewController()

        add(buyNowWorksVC, toParent: viewController, withTopMargin: "0", sideMargin: "0")

        let artworks = promotedSaleArtworks.map { $0.artwork }
        // Basically only show the saleMessage if there is a price
        artworks.forEach {
            if($0.isPriceHidden.boolValue || $0.price.count == 0) {
                $0.saleMessage = ""
            }
        }

        buyNowWorksVC.activeModule = module
        buyNowWorksVC.constrainHeightAutomatically = true
        buyNowWorksVC.appendItems(artworks)
        buyNowWorksVC.delegate = self

        let bottomBorder = UIView()
        bottomBorder.backgroundColor = .artsyGrayRegular()
        bottomBorder.constrainHeight("1")
        addSubview(bottomBorder, withTopMargin: "2", sideMargin: "0")

        bottomMarginHeight = 2

        self.embeddedVC = buyNowWorksVC
        self.isCompact = isCompact
        self.saleArtworks = promotedSaleArtworks
        self.actionDelegate = delegate
    }

    override func updateConstraints() {
        self.embeddedVC?.activeModule = self.embeddedVC?.activeModule
        self.embeddedVC?.collectionView.reloadData()
        self.embeddedVC?.updateViewConstraints()
        super.updateConstraints()
    }
}

fileprivate typealias EmbeddedModelCallbacks = AuctionBuyNowView
extension EmbeddedModelCallbacks: AREmbeddedModelsViewControllerDelegate {
    func embeddedModelsViewController(_ controller: AREmbeddedModelsViewController!, didTapItemAt index: UInt) {
        guard let artwork = controller.items?[Int(index)] as? Artwork else {
            return
        }
        let viewController = ARComponentViewController.module("Artwork", withProps: ["artworkID": artwork.artworkID])
        self.actionDelegate?.navigationController?.pushViewController(viewController, animated: true)
    }

    func embeddedModelsViewController(_ controller: AREmbeddedModelsViewController!, shouldPresent viewController: UIViewController!) {
        self.actionDelegate?.navigationController?.pushViewController(viewController, animated: true)
    }
}
