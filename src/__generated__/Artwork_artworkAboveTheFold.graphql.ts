/* tslint:disable */
/* eslint-disable */

import { ReaderFragment } from "relay-runtime";
import { FragmentRefs } from "relay-runtime";
export type Artwork_artworkAboveTheFold = {
    readonly slug: string;
    readonly internalID: string;
    readonly id: string;
    readonly title: string | null;
    readonly artist: {
        readonly name: string | null;
    } | null;
    readonly medium: string | null;
    readonly is_acquireable: boolean | null;
    readonly is_offerable: boolean | null;
    readonly is_biddable: boolean | null;
    readonly is_inquireable: boolean | null;
    readonly availability: string | null;
    readonly " $fragmentRefs": FragmentRefs<"ArtworkHeader_artwork" | "CommercialInformation_artwork">;
    readonly " $refType": "Artwork_artworkAboveTheFold";
};
export type Artwork_artworkAboveTheFold$data = Artwork_artworkAboveTheFold;
export type Artwork_artworkAboveTheFold$key = {
    readonly " $data"?: Artwork_artworkAboveTheFold$data;
    readonly " $fragmentRefs": FragmentRefs<"Artwork_artworkAboveTheFold">;
};



const node: ReaderFragment = {
  "kind": "Fragment",
  "name": "Artwork_artworkAboveTheFold",
  "type": "Artwork",
  "metadata": null,
  "argumentDefinitions": [],
  "selections": [
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "slug",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "internalID",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "id",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "title",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "LinkedField",
      "alias": null,
      "name": "artist",
      "storageKey": null,
      "args": null,
      "concreteType": "Artist",
      "plural": false,
      "selections": [
        {
          "kind": "ScalarField",
          "alias": null,
          "name": "name",
          "args": null,
          "storageKey": null
        }
      ]
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "medium",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "is_acquireable",
      "name": "isAcquireable",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "is_offerable",
      "name": "isOfferable",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "is_biddable",
      "name": "isBiddable",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": "is_inquireable",
      "name": "isInquireable",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "ScalarField",
      "alias": null,
      "name": "availability",
      "args": null,
      "storageKey": null
    },
    {
      "kind": "FragmentSpread",
      "name": "ArtworkHeader_artwork",
      "args": null
    },
    {
      "kind": "FragmentSpread",
      "name": "CommercialInformation_artwork",
      "args": null
    }
  ]
};
(node as any).hash = '41d78f5c61faaf27210fd00d32ce3930';
export default node;
