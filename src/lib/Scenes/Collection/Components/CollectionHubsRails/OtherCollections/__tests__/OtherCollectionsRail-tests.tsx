import SwitchBoard from "lib/NativeModules/SwitchBoard"
import { CollectionHubRailsOtherCollectionsRailFixture } from "lib/Scenes/Collection/Components/__fixtures__/CollectionFixture"
import { renderWithWrappers } from "lib/tests/renderWithWrappers"
import { Sans } from "palette"
import React from "react"
import { TouchableOpacity } from "react-native"
import { CollectionGroupMemberPill, OtherCollectionsRail } from "../OtherCollectionsRail"

jest.mock("lib/NativeModules/SwitchBoard", () => ({ presentNavigationViewController: jest.fn() }))

describe("Other Collections Rail", () => {
  const TestRenderer = () => (
    <OtherCollectionsRail {...({ collectionGroup: CollectionHubRailsOtherCollectionsRailFixture } as any)} />
  )

  it("renders a title", () => {
    const { root } = renderWithWrappers(<TestRenderer />)
    const {
      props: { children },
    } = root.findByType(Sans)

    expect(children).toContain("Browse by Movement")
  })

  it("renders the other collection pills", () => {
    const { root } = renderWithWrappers(<TestRenderer />)

    expect(root.findAllByType(CollectionGroupMemberPill).map(({ props: { children } }) => children)).toEqual([
      "Abstract Expressionist Art",
      "Arte Povera",
      "Black Arts Movement",
    ])
  })

  it("navigates to a new collection when a pill is tapped", () => {
    const { root } = renderWithWrappers(<TestRenderer />)
    const [button] = root.findAllByType(TouchableOpacity)

    button.props.onPress()

    expect(SwitchBoard.presentNavigationViewController).toHaveBeenCalledWith(
      expect.anything(),
      "/collection/abstract-expressionism"
    )
  })
})
