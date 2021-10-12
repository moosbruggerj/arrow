module Models.Arrow exposing(Id, Arrow, idDecoder, decoder, encode, encodeId)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Decode as MD
import Json.Encode as Encode
import Models.Encode as E
import Models.Bow as Bow

type Id
    = Id Int

type alias Arrow =
  { id: Id
  , name: Maybe String
  , headWeight: Maybe Float
  , spline: Maybe Float
  , featherLength: Maybe Float
  , featherType: Maybe String
  , length: Float
  , weight: Float
  , bowId: Bow.Id
  }

idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

decoder: Decoder Arrow
decoder =
  Decode.succeed Arrow
    |> D.required "id" idDecoder
    |> MD.maybe "name" Decode.string
    |> MD.maybe "head_weight" Decode.float
    |> MD.maybe "spline" Decode.float
    |> MD.maybe "feather_length" Decode.float
    |> MD.maybe "feather_type" Decode.string
    |> D.required "length" Decode.float
    |> D.required "weight" Decode.float
    |> D.required "bow_id" Bow.idDecoder

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encode: Arrow -> Encode.Value
encode { id, name, headWeight, spline, featherLength, featherType, length, weight, bowId } =
  E.object
    [ E.required "id" encodeId id
    , E.maybe "name" Encode.string name
    , E.maybe "head_weight" Encode.float headWeight
    , E.maybe "spline" Encode.float spline
    , E.maybe "feather_length" Encode.float featherLength
    , E.maybe "feather_type" Encode.string featherType
    , E.required "length" Encode.float length
    , E.required "weight" Encode.float weight
    , E.required "bow_id" Bow.encodeId bowId
    ]
