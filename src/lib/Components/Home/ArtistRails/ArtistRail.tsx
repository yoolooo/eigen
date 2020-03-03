// TODO: This file still has a bunch of faffing with rendering a relay based version of ArtistCard and a plain React
//       version. In reality it should be updated to never render the React component but instead update the store and
//       let Relay re-render the cards.

import React, { Component } from "react"
import { Animated, Easing, View, ViewProperties } from "react-native"
import { commitMutation, createFragmentContainer, graphql, RelayProp } from "react-relay"

import { Schema, Track, track as _track } from "lib/utils/track"
import Separator from "../../Separator"
import Spinner from "../../Spinner"
import { ArtistCard, ArtistCardContainer } from "./ArtistCard"

import { ArtistCard_artist } from "__generated__/ArtistCard_artist.graphql"
import { ArtistRail_rail } from "__generated__/ArtistRail_rail.graphql"
import { ArtistRailFollowMutation } from "__generated__/ArtistRailFollowMutation.graphql"
import Events from "lib/NativeModules/Events"
import { defaultEnvironment } from "lib/relay/createEnvironment"
import styled from "styled-components/native"
import { CardScrollView } from "../CardScrollView"

const Animation = {
  yDelta: 20,
  duration: {
    followedArtist: 500,
    suggestedArtist: 400,
  },
  easing: Easing.out(Easing.cubic),
}

interface SuggestedArtist extends Pick<ArtistCard_artist, Exclude<keyof ArtistCard_artist, " $refType">> {
  _animatedValues?: {
    opacity: Animated.Value
    translateY: Animated.Value
  }
}

interface Props extends ViewProperties {
  relay: RelayProp
  rail: ArtistRail_rail
}

interface State {
  artists: SuggestedArtist[]
}

const track: Track<Props, State> = _track

@track()
export class ArtistRail extends Component<Props, State> {
  constructor(props: Props) {
    super(props)
    if (props.rail.results) {
      const artists = props.rail.results.map(artist => setupSuggestedArtist(artist, 1, 0)) as any
      this.state = { artists }
    }
  }

  followedArtistAnimation(followedArtist) {
    return new Promise((resolve, _reject) => {
      const { opacity, translateY } = followedArtist._animatedValues
      const duration = Animation.duration.followedArtist
      const easing = Animation.easing
      Animated.parallel([
        Animated.timing(opacity, { duration, easing, toValue: 0 }),
        Animated.timing(translateY, { duration, easing, toValue: Animation.yDelta }),
      ]).start(resolve)
    })
  }

  suggestedArtistAnimation(suggestedArtist: SuggestedArtist) {
    return new Promise((resolve, _reject) => {
      const { opacity, translateY } = suggestedArtist._animatedValues
      const duration = Animation.duration.suggestedArtist
      const easing = Animation.easing
      Animated.parallel([
        Animated.timing(opacity, { duration, easing, toValue: 1 }),
        Animated.timing(translateY, { duration, easing, toValue: 0 }),
      ]).start(resolve)
    })
  }

  replaceFollowedArtist(followedArtist, suggestedArtist: SuggestedArtist): Promise<undefined> {
    const artists = this.state.artists.slice(0)
    const index = artists.indexOf(followedArtist)
    if (suggestedArtist) {
      artists[index] = suggestedArtist
    } else {
      // remove card when there is no suggestion
      artists.splice(index, 1)
    }
    // Resolve after re-render
    return new Promise(resolve => {
      this.setState({ artists }, resolve)
    })
  }

  followArtistAndFetchNewSuggestion(followArtist: SuggestedArtist) {
    return new Promise<SuggestedArtist | null>((resolve, reject) => {
      commitMutation<ArtistRailFollowMutation>(defaultEnvironment, {
        mutation: graphql`
          mutation ArtistRailFollowMutation($input: FollowArtistInput!, $excludeArtistIDs: [String]!) {
            followArtist(input: $input) {
              artist {
                related {
                  suggestedConnection(
                    first: 1
                    excludeArtistIDs: $excludeArtistIDs
                    excludeFollowedArtists: true
                    excludeArtistsWithoutForsaleArtworks: true
                  ) {
                    edges {
                      node {
                        ...ArtistCard_artist
                      }
                    }
                  }
                }
              }
            }
          }
        `,
        variables: {
          input: { artistID: followArtist.internalID },
          excludeArtistIDs: this.state.artists.map(({ internalID }) => internalID),
        },
        onError: reject,
        onCompleted: (response, errors) => {
          if (errors && errors.length > 0) {
            reject(new Error(JSON.stringify(errors)))
          } else {
            Events.postEvent({
              name: "Follow artist",
              artist_id: followArtist.internalID,
              artist_slug: followArtist.slug,
              source_screen: "home page",
              context_module: "artist rail",
            })

            const [edge] = response.followArtist.artist.related.suggestedConnection.edges
            resolve(edge ? setupSuggestedArtist(edge.node, 0, -Animation.yDelta) : null)
          }
        },
      })
    })
  }

  @track((_props, _state, [followArtist]) => ({
    action_name: Schema.ActionNames.HomeArtistRailFollow,
    action_type: Schema.ActionTypes.Tap,
    owner_id: followArtist.internalID,
    owner_slug: followArtist.id,
    owner_type: Schema.OwnerEntityTypes.Artist,
  }))
  async handleFollowChange(followArtist: SuggestedArtist, completionHandler: (followStatus: boolean) => void) {
    try {
      const suggestion = await this.followArtistAndFetchNewSuggestion(followArtist)
      completionHandler(true)
      if (suggestion) {
        await this.followedArtistAnimation(followArtist)
        await this.replaceFollowedArtist(followArtist, suggestion)
        await this.suggestedArtistAnimation(suggestion)
      }
    } catch (error) {
      console.warn(error)
      completionHandler(false)
    }
  }

  renderModuleResults() {
    if (this.state.artists.length > 0) {
      const cards = this.state.artists.map(artist => {
        // Compose key, because an artist may appear twice on the home view in different modules.
        const key = this.props.rail.id + artist.id
        const { opacity, translateY } = artist._animatedValues
        const style = { opacity, transform: [{ translateY }] }
        return (
          <Animated.View key={key} style={style}>
            {artist.hasOwnProperty("__fragments") ? (
              <ArtistCardContainer
                artist={artist as any}
                onFollow={completionHandler => this.handleFollowChange(artist, completionHandler)}
              />
            ) : (
              <ArtistCard
                artist={artist as any}
                onFollow={completionHandler => this.handleFollowChange(artist, completionHandler)}
                key={key}
              />
            )}
          </Animated.View>
        )
      })
      return <CardScrollView>{cards}</CardScrollView>
    } else {
      return <Spinner style={{ flex: 1, marginBottom: 20 }} />
    }
  }

  title() {
    // TODO: Once Title is updated to styled-components, update the copy to spec
    switch (this.props.rail.key) {
      case "TRENDING":
        return "Trending artists"
      case "SUGGESTED":
        return "Recommended artists"
      case "POPULAR":
        return "Popular artists"
    }
  }

  render() {
    return this.state.artists.length ? (
      <View>
        <Title>{this.title()}</Title>
        {this.renderModuleResults()}
        <Separator />
      </View>
    ) : null
  }
}

// TODO: Specs say this should be Sans, but let's update all Home titles at once
// and convert to styled-components
const Title = styled.Text`
  margin: 30px 20px 10px;
  font-size: 30px;
  /* stylelint-disable */
  font-family: AGaramondPro-Regular;
  /* stylelint-enable */
`

const setupSuggestedArtist = (artist, opacity, translateY) =>
  ({
    ...artist,
    _animatedValues: {
      opacity: new Animated.Value(opacity),
      translateY: new Animated.Value(translateY),
    },
  } as SuggestedArtist)

export default createFragmentContainer(ArtistRail, {
  rail: graphql`
    fragment ArtistRail_rail on HomePageArtistModule {
      id
      key
      results {
        id
        internalID
        ...ArtistCard_artist
      }
    }
  `,
})