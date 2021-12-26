module Models.Bow exposing (Id, Bow, encode, decoder, idDecoder, encodeId, idToString, Data, encodeData, idToInt)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Json.Encode as Encode
import Models.Encode as E
import Models
import Units.Length as Length exposing (Length)

type Id
    = Id Int

type alias Bow = Models.Persisted Id Data

type alias Data = 
  { name: String
  , maxDrawDistance: Length
  , remainderArrowLength: Length
  }

cBow : Id -> String -> Length -> Length -> Bow
cBow id name maxDrawDistance remainderArrowLength = 
  Models.Persisted id 
    <| Data name maxDrawDistance remainderArrowLength

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encode: Bow -> Encode.Value
encode bow =
  Models.encode bow encodeId dataEncoder

encodeData: Data -> Encode.Value
encodeData bow =
  E.object
    (dataEncoder bow)

dataEncoder: Data -> List (Maybe ( String, Encode.Value ))
dataEncoder { name, maxDrawDistance, remainderArrowLength } =
  [ E.required "name" Encode.string name
  , E.required "max_draw_distance" Length.encode maxDrawDistance
  , E.required "remainderArrowLength" Length.encode remainderArrowLength
  ]

idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

decoder: Decoder Bow
decoder =
  Decode.succeed cBow
    |> D.required "id" idDecoder
    |> D.required "name" Decode.string
    |> D.required "max_draw_distance" Length.decoder
    |> D.required "remainder_arrow_length" Length.decoder

idToString: Id -> String
idToString (Id id) =
  String.fromInt id

idToInt: Id -> Int
idToInt (Id id) =
    id
