import { Sale_sale } from "__generated__/Sale_sale.graphql"
import { SectionTitle } from "lib/Components/SectionTitle"
import { SmallTileRailContainer } from "lib/Scenes/Home/Components/SmallTileRail"
import { Flex } from "palette"
import React, { useRef } from "react"
import { FlatList, View } from "react-native"

interface Props {
  saleArtworks: NonNullable<NonNullable<NonNullable<NonNullable<Sale_sale["saleArtworksConnection"]>["edges"]>[0]>>
}

export const SaleArtworksRail: React.FC<Props> = ({ saleArtworks }) => {
  const saleArtworksRailRef = useRef<FlatList<any>>(null)
  const artworks = saleArtworks.map((saleArtwork) => saleArtwork.artwork)

  return (
    <View>
      <Flex mx="2">
        <SectionTitle title="Lots by artists you follow" />
      </Flex>
      <SmallTileRailContainer
        listRef={saleArtworksRailRef}
        artworks={artworks}
        contextModule={null as any}
        showLotNumber
      />
    </View>
  )
}
