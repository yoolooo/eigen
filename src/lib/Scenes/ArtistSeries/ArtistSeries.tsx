import { OwnerType } from "@artsy/cohesion"
import { ArtistSeries_artistSeries } from "__generated__/ArtistSeries_artistSeries.graphql"
import { ArtistSeriesQuery } from "__generated__/ArtistSeriesQuery.graphql"
import { defaultEnvironment } from "lib/relay/createEnvironment"
import { ArtistSeriesArtworksFragmentContainer } from "lib/Scenes/ArtistSeries/ArtistSeriesArtworks"
import { ArtistSeriesHeaderFragmentContainer } from "lib/Scenes/ArtistSeries/ArtistSeriesHeader"
import { ArtistSeriesMetaFragmentContainer } from "lib/Scenes/ArtistSeries/ArtistSeriesMeta"
import { ArtistSeriesMoreSeriesFragmentContainer } from "lib/Scenes/ArtistSeries/ArtistSeriesMoreSeries"
import renderWithLoadProgress from "lib/utils/renderWithLoadProgress"
import { ProvideScreenTracking } from "lib/utils/track"
import { Box, Theme } from "palette"
import React from "react"

import { OwnerEntityTypes, PageNames } from "lib/utils/track/schema"
import { ScrollView } from "react-native"
import { createFragmentContainer, graphql, QueryRenderer } from "react-relay"
interface ArtistSeriesProps {
  artistSeries: ArtistSeries_artistSeries
}

export const ArtistSeries: React.FC<ArtistSeriesProps> = ({ artistSeries }) => {
  const artist = artistSeries.artist?.[0]

  return (
    <ProvideScreenTracking
      info={{
        context_screen: PageNames.ArtistSeriesPage,
        context_screen_owner_type: OwnerEntityTypes.ArtistSeries,
        context_screen_owner_slug: artistSeries.slug,
        context_screen_owner_id: artistSeries.internalID,
      }}
    >
      <Theme>
        <ScrollView showsVerticalScrollIndicator={false}>
          <Box px={2}>
            <ArtistSeriesHeaderFragmentContainer artistSeries={artistSeries} />
            <ArtistSeriesMetaFragmentContainer artistSeries={artistSeries} />
            <ArtistSeriesArtworksFragmentContainer artistSeries={artistSeries} />
          </Box>
          {
            /* We don't want to see ArtistSeriesMoreSeries or the Separator when there are no related artist series.
            However, this component doesn't have access to the count of related artist series. So, we implement the
            Separator using a border instead, which won't show when there are no children in ArtistSeriesMoreSeries.
          */
            !!artist && (
              <ArtistSeriesMoreSeriesFragmentContainer
                contextScreenOwnerId={artistSeries.internalID}
                contextScreenOwnerSlug={artistSeries.slug}
                contextScreenOwnerType={OwnerType.artistSeries}
                artist={artist}
                borderTopWidth="1px"
                borderTopColor="black10"
                pt={2}
                px={2}
                artistSeriesHeader="More series by this artist"
                currentArtistSeriesExcluded
              />
            )
          }
        </ScrollView>
      </Theme>
    </ProvideScreenTracking>
  )
}

export const ArtistSeriesFragmentContainer = createFragmentContainer(ArtistSeries, {
  artistSeries: graphql`
    fragment ArtistSeries_artistSeries on ArtistSeries {
      internalID
      slug

      artistIDs

      ...ArtistSeriesHeader_artistSeries
      ...ArtistSeriesMeta_artistSeries
      ...ArtistSeriesArtworks_artistSeries

      artist: artists(size: 1) {
        ...ArtistSeriesMoreSeries_artist
      }
    }
  `,
})

export const ArtistSeriesQueryRenderer: React.FC<{ artistSeriesID: string }> = ({ artistSeriesID }) => {
  return (
    <QueryRenderer<ArtistSeriesQuery>
      environment={defaultEnvironment}
      query={graphql`
        query ArtistSeriesQuery($artistSeriesID: ID!) {
          artistSeries(id: $artistSeriesID) {
            ...ArtistSeries_artistSeries
          }
        }
      `}
      cacheConfig={{ force: true }}
      variables={{
        artistSeriesID,
      }}
      render={renderWithLoadProgress(ArtistSeriesFragmentContainer)}
    />
  )
}
