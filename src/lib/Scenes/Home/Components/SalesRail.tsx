import { SalesRail_salesModule } from "__generated__/SalesRail_salesModule.graphql"
import { Flex, Sans } from "palette"
import React, { useImperativeHandle, useRef } from "react"
import { FlatList, View } from "react-native"
import { createFragmentContainer, graphql } from "react-relay"

import ImageView from "lib/Components/OpaqueImageView/OpaqueImageView"
import { SectionTitle } from "lib/Components/SectionTitle"
import { useTracking } from "react-tracking"

import {
  CARD_RAIL_ARTWORKS_HEIGHT as ARTWORKS_HEIGHT,
  CardRailArtworkImageContainer as ArtworkImageContainer,
  CardRailCard,
  CardRailDivision as Division,
  CardRailMetadataContainer as MetadataContainer,
} from "lib/Components/Home/CardRailCard"
import { CardRailFlatList } from "lib/Components/Home/CardRailFlatList"
import { navigate } from "lib/navigation/navigate"
import { extractNodes } from "lib/utils/extractNodes"
import { capitalize, compact } from "lodash"
import HomeAnalytics from "../homeAnalytics"
import { RailScrollProps } from "./types"

interface Props {
  salesModule: SalesRail_salesModule
}

type Sale = SalesRail_salesModule["results"][0]

const SalesRail: React.FC<Props & RailScrollProps> = (props) => {
  const listRef = useRef<FlatList<any>>()
  const tracking = useTracking()

  useImperativeHandle(props.scrollRef, () => ({
    scrollToTop: () => listRef.current?.scrollToOffset({ offset: 0, animated: false }),
  }))

  return (
    <View>
      <Flex pl="2" pr="2">
        <SectionTitle
          title="Auctions"
          subtitle="Bid online in live and timed auctions"
          onPress={() => {
            tracking.trackEvent(HomeAnalytics.auctionHeaderTapEvent())
            navigate("/auctions")
          }}
        />
      </Flex>

      <CardRailFlatList<Sale>
        listRef={listRef}
        data={props.salesModule.results}
        renderItem={({ item: result, index }) => {
          // Sales are expected to always have >= 2 artworks, but we should
          // still be cautious to avoid crashes if this assumption is broken.
          const availableArtworkImageURLs = compact(
            extractNodes(result?.saleArtworksConnection, (artwork) => artwork.artwork?.image?.url)
          )

          // Ensure we have an array of exactly 3 URLs, copying over the last image if we have less than 3
          const artworkImageURLs = [null, null, null].reduce((acc: string[], _, i) => {
            return [...acc, availableArtworkImageURLs[i] || acc[i - 1]]
          }, [])

          return (
            <CardRailCard
              key={result?.href! /* STRICTNESS_MIGRATION */}
              onPress={() => {
                tracking.trackEvent(HomeAnalytics.auctionThumbnailTapEvent(result?.internalID, result?.slug, index))
                const url = result?.liveURLIfOpen ?? result?.href
                if (url) {
                  navigate(url)
                }
              }}
            >
              <View>
                <ArtworkImageContainer>
                  <ImageView width={ARTWORKS_HEIGHT} height={ARTWORKS_HEIGHT} imageURL={artworkImageURLs[0]} />
                  <Division />
                  <View>
                    <ImageView
                      width={ARTWORKS_HEIGHT / 2}
                      height={ARTWORKS_HEIGHT / 2}
                      imageURL={artworkImageURLs[1]}
                    />
                    <Division horizontal />
                    <ImageView
                      width={ARTWORKS_HEIGHT / 2}
                      height={ARTWORKS_HEIGHT / 2}
                      imageURL={artworkImageURLs[2]}
                    />
                  </View>
                </ArtworkImageContainer>
                <MetadataContainer>
                  <Sans numberOfLines={2} weight="medium" size="3t">
                    {result?./* STRICTNESS_MIGRATION */ name}
                  </Sans>
                  <Sans numberOfLines={1} size="3t" color="black60" data-test-id="sale-subtitle">
                    {!!result?./* STRICTNESS_MIGRATION */ liveStartAt ? "Live Auction" : "Timed Auction"} •{" "}
                    {capitalize(result?.displayTimelyAt! /* STRICTNESS_MIGRATION */)}
                  </Sans>
                </MetadataContainer>
              </View>
            </CardRailCard>
          )
        }}
      />
    </View>
  )
}

export const SalesRailFragmentContainer = createFragmentContainer(SalesRail, {
  salesModule: graphql`
    fragment SalesRail_salesModule on HomePageSalesModule {
      results {
        id
        slug
        internalID
        href
        name
        liveURLIfOpen
        liveStartAt
        displayTimelyAt
        saleArtworksConnection(first: 3) {
          edges {
            node {
              artwork {
                image {
                  url(version: "large")
                }
              }
            }
          }
        }
      }
    }
  `,
})
