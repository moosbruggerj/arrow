module Models.Bow exposing (Id, Bow, encode, decoder, idDecoder, encodeId)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Json.Encode as Encode
import Models.Encode as E

type Id
    = Id Int

type alias Bow =
  { id: Id
  , name: String
  , maxDrawDistance: Float
  , remainderArrowLength: Float
  }

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encode: Bow -> Encode.Value
encode { id, name, maxDrawDistance, remainderArrowLength } =
  E.object
    [ E.required "id" encodeId id
    , E.required "name" Encode.string name
    , E.required "max_draw_distance" Encode.float maxDrawDistance
    , E.required "remainderArrowLength" Encode.float remainderArrowLength
    ]


idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

decoder: Decoder Bow
decoder =
  Decode.succeed Bow
    |> D.required "id" idDecoder
    |> D.required "name" Decode.string
    |> D.required "max_draw_distance" Decode.float
    |> D.required "remainder_arrow_length" Decode.float

