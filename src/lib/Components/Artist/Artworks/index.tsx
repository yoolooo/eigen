import { Artworks_artist } from "__generated__/Artworks_artist.graphql"
import {
  InfiniteScrollArtworksGridContainer as InfiniteScrollArtworksGrid,
  Props as InfiniteScrollGridProps,
} from "lib/Components/ArtworkGrids/InfiniteScrollArtworksGrid"
import React from "react"
import { createPaginationContainer, graphql, RelayPaginationProp } from "react-relay"

interface Props extends InfiniteScrollGridProps {
  artist: Artworks_artist
  relay: RelayPaginationProp
}

const ArtworksGrid: React.FC<Props> = ({ artist, relay, ...props }) => (
  <InfiniteScrollArtworksGrid connection={artist.artworks} loadMore={relay.loadMore} {...props} />
)

export default createPaginationContainer(
  ArtworksGrid,
  {
    artist: graphql`
      fragment Artworks_artist on Artist
        @argumentDefinitions(count: { type: "Int", defaultValue: 10 }, cursor: { type: "String" }) {
        id
        artworks: filterArtworksConnection(
          first: $count
          after: $cursor
          sort: "-decayed_merch"
          aggregations: [TOTAL]
        ) @connection(key: "ArtistArtworksGrid_artworks") {
          # TODO: Just here to satisfy the relay compiler, can we get rid of this need?
          edges {
            node {
              id
            }
          }
          ...InfiniteScrollArtworksGrid_connection
        }
      }
    `,
  },
  {
    direction: "forward",
    getConnectionFromProps(props) {
      return props.artist && props.artist.artworks
    },
    getFragmentVariables(prevVars, totalCount) {
      return {
        ...prevVars,
        count: totalCount,
      }
    },
    getVariables(props, { count, cursor }, { filter }) {
      return {
        id: props.artist.id,
        count,
        cursor,
        filter,
      }
    },
    query: graphql`
      query ArtworksArtistQuery($id: ID!, $count: Int!, $cursor: String) {
        node(id: $id) {
          ... on Artist {
            ...Artworks_artist @arguments(count: $count, cursor: $cursor)
          }
        }
      }
    `,
  }
)
