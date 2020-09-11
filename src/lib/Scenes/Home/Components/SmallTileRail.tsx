import * as Analytics from "@artsy/cohesion"
import { SmallTileRail_artworks } from "__generated__/SmallTileRail_artworks.graphql"
import { AboveTheFoldFlatList } from "lib/Components/AboveTheFoldFlatList"
import { saleMessageOrBidInfo } from "lib/Components/ArtworkGrids/ArtworkGridItem"
import { ArtworkTileRailCard } from "lib/Components/ArtworkTileRail"
import SwitchBoard from "lib/NativeModules/SwitchBoard"
import { Spacer } from "palette"
import React from "react"
import { FlatList } from "react-native"
import { createFragmentContainer, graphql } from "react-relay"
import { useTracking } from "react-tracking"
import { getUrgencyTag } from "../../../utils/getUrgencyTag"
import HomeAnalytics from "../homeAnalytics"

interface Props {
  artworks: SmallTileRail_artworks
  listRef: React.RefObject<FlatList<any>>
  contextModule: Analytics.ContextModule | undefined
  showLotNumber?: boolean
}

const SmallTileRail: React.FC<Props> = ({ artworks, listRef, contextModule, showLotNumber }) => {
  const tracking = useTracking()
  return (
    <AboveTheFoldFlatList
      listRef={listRef}
      horizontal
      ListHeaderComponent={() => <Spacer mr={2}></Spacer>}
      ListFooterComponent={() => <Spacer mr={2}></Spacer>}
      ItemSeparatorComponent={() => <Spacer width={15}></Spacer>}
      showsHorizontalScrollIndicator={false}
      data={artworks}
      initialNumToRender={4}
      windowSize={3}
      renderItem={({ item, index }) => (
        <ArtworkTileRailCard
          onPress={
            item.href
              ? () => {
                  if (contextModule) {
                    tracking.trackEvent(
                      HomeAnalytics.artworkThumbnailTapEvent(contextModule, item.slug, index, "single")
                    )
                  }
                  SwitchBoard.presentNavigationViewController(listRef.current!, item.href!)
                }
              : undefined
          }
          imageURL={item.image?.imageURL ?? ""}
          imageSize="small"
          useSquareAspectRatio
          artistNames={item.artistNames}
          saleMessage={saleMessageOrBidInfo({ artwork: item, isSmallTile: true })}
          urgencyTag={item?.sale?.isAuction && !item?.sale?.isClosed ? getUrgencyTag(item?.sale?.endAt) : null}
          showLotNumber={showLotNumber}
        />
      )}
      keyExtractor={(item, index) => String(item.image?.imageURL || index)}
    />
  )
}

export const SmallTileRailContainer = createFragmentContainer(SmallTileRail, {
  artworks: graphql`
    fragment SmallTileRail_artworks on Artwork @relay(plural: true) {
      href
      saleMessage
      artistNames
      slug
      internalID
      sale {
        isAuction
        isClosed
        displayTimelyAt
        endAt
      }
      saleArtwork {
        counts {
          bidderPositions
        }
        currentBid {
          display
        }
      }
      partner {
        name
      }
      image {
        imageURL
      }
    }
  `,
})
