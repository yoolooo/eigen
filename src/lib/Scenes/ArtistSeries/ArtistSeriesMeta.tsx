import { EntityHeader, Sans, Spacer } from "@artsy/palette"
import { ArtistSeriesMeta_artistSeries } from "__generated__/ArtistSeriesMeta_artistSeries.graphql"
import { ArtistSeriesMetaFollowMutation } from "__generated__/ArtistSeriesMetaFollowMutation.graphql"
import { ReadMore } from "lib/Components/ReadMore"
import SwitchBoard from "lib/NativeModules/SwitchBoard"
import { truncatedTextLimit } from "lib/utils/hardware"
import React, { useRef } from "react"
import { TouchableOpacity, TouchableWithoutFeedback, View } from "react-native"
import { commitMutation, createFragmentContainer, graphql, RelayProp } from "react-relay"

interface ArtistSeriesMetaProps {
  artistSeries: ArtistSeriesMeta_artistSeries
  relay: RelayProp
}

type ArtistToFollowOrUnfollow = NonNullable<NonNullable<ArtistSeriesMetaProps["artistSeries"]["artists"]>[0]>

export const ArtistSeriesMeta: React.SFC<ArtistSeriesMetaProps> = ({ artistSeries, relay }) => {
  const metaRef = useRef<View | null>(null)
  const maxChars = truncatedTextLimit()
  const artist = artistSeries?.artists?.[0]

  const followOrUnfollowArtist = (followArtist: ArtistToFollowOrUnfollow) => {
    return new Promise<void>((resolve, reject) => {
      commitMutation<ArtistSeriesMetaFollowMutation>(relay.environment, {
        mutation: graphql`
          mutation ArtistSeriesMetaFollowMutation($input: FollowArtistInput!) {
            followArtist(input: $input) {
              artist {
                isFollowed
              }
            }
          }
        `,
        variables: {
          input: { artistID: followArtist.internalID, unfollow: followArtist.isFollowed },
        },
        onError: reject,
        onCompleted: (_response, errors) => {
          if (errors && errors.length > 0) {
            reject(new Error(JSON.stringify(errors)))
          } else {
            resolve()
          }
        },
      })
    })
  }

  return (
    <View ref={metaRef}>
      <Sans size="8" mt={3} data-test-id="title">
        {artistSeries.title}
      </Sans>
      {!!artist && (
        <TouchableOpacity
          key={artist.id!}
          onPress={() => {
            SwitchBoard.presentNavigationViewController(metaRef.current!, `/artist/${artist.slug}`)
          }}
        >
          <Spacer my={0.5} />
          <EntityHeader
            smallVariant
            name={artist.name!}
            imageUrl={artist.image?.url!}
            FollowButton={
              <TouchableWithoutFeedback
                onPress={() => followOrUnfollowArtist(artist)}
                hitSlop={{ top: 20, left: 20, bottom: 20, right: 20 }}
              >
                <Sans style={{ textDecorationLine: "underline" }} size="3">
                  {artist.isFollowed ? "Following" : "Follow"}
                </Sans>
              </TouchableWithoutFeedback>
            }
          />
          <Spacer my={0.5} />
        </TouchableOpacity>
      )}
      <ReadMore
        data-test-id="description"
        textStyle="new"
        content={artistSeries?.description ?? ""}
        maxChars={maxChars}
      />
    </View>
  )
}

export const ArtistSeriesMetaFragmentContainer = createFragmentContainer(ArtistSeriesMeta, {
  artistSeries: graphql`
    fragment ArtistSeriesMeta_artistSeries on ArtistSeries {
      title
      description
      artists(size: 1) {
        id
        internalID
        name
        slug
        isFollowed
        image {
          url
        }
      }
    }
  `,
})