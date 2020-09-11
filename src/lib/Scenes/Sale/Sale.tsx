import { Sale_sale$key } from "__generated__/Sale_sale.graphql"
import Spinner from "lib/Components/Spinner"
import { Flex, Sans, Separator } from "palette"

import { SaleQueryRendererQuery } from "__generated__/SaleQueryRendererQuery.graphql"
import { defaultEnvironment } from "lib/relay/createEnvironment"
import { extractNodes } from "lib/utils/extractNodes"
import { renderWithPlaceholder } from "lib/utils/renderWithPlaceholder"
import React from "react"
import { graphql, QueryRenderer } from "react-relay"
import { useFragment } from "relay-hooks"
import { SaleArtworksRail } from "./Components/SaleArtworksRail"

interface Props {
  sale: Sale_sale$key
}

export const Sale: React.FC<Props> = (props) => {
  const sale = useFragment(SaleFragmentSpec, props.sale)
  const saleArtworks = extractNodes(sale.saleArtworksConnection)

  return (
    <Flex>
      <Sans size="4t">Sale name: {sale.name}</Sans>
      <Separator marginTop={100} />
      {saleArtworks.length > 0 && <SaleArtworksRail saleArtworks={saleArtworks} />}
    </Flex>
  )
}

const SaleArtworkFragmentSpec = graphql`
  fragment SaleArtwork_saleArtwork on SaleArtwork {
    artwork {
      image {
        url(version: "small")
      }
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
    lotLabel
  }
`

const SaleFragmentSpec = graphql`
  fragment Sale_sale on Sale {
    name
    saleArtworksConnection(first: 10) {
      edges {
        node {
          ...SaleArtworkFragmentSpec
        }
      }
    }
  }
`

const Placeholder = () => <Spinner style={{ flex: 1 }} />

export const SaleQueryRenderer: React.FC<{ saleID: string }> = ({ saleID }) => {
  return (
    <QueryRenderer<SaleQueryRendererQuery>
      environment={defaultEnvironment}
      query={graphql`
        query SaleQueryRendererQuery($saleID: String!) {
          sale(id: $saleID) {
            ...Sale_sale
          }
        }
      `}
      render={renderWithPlaceholder({
        Container: Sale,
        renderPlaceholder: () => <Placeholder />,
      })}
      variables={{ saleID }}
    />
  )
}
