module Models.MeasurePoint exposing(Id, MeasurePoint, idDecoder, decoder, encode, encodeId)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Decode as MD
import Json.Encode as Encode
import Models.Encode as E
import Models.Measure as Measure

type Id
    = Id Int

type TimeOffset
    = TimeOffset Int

type alias MeasurePoint =
  { id: Id
  , time: TimeOffset
  , drawDistance: Float
  , force: Float
  , measureId: Measure.Id
  }

idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

timeOffsetDecoder: Decoder TimeOffset
timeOffsetDecoder =
  Decode.map TimeOffset Decode.int

decoder: Decoder MeasurePoint
decoder =
  Decode.succeed MeasurePoint
    |> D.required "id" idDecoder
    |> D.required "time" timeOffsetDecoder
    |> D.required "draw_distance" Decode.float
    |> D.required "force" Decode.float
    |> D.required "measure_id" Measure.idDecoder

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encodeTimeOffset: TimeOffset -> Encode.Value
encodeTimeOffset (TimeOffset time) =
  Encode.int time

encode: MeasurePoint -> Encode.Value
encode { id, time, drawDistance, force, measureId } =
  E.object
    [ E.required "id" encodeId id
    , E.required "time" encodeTimeOffset time
    , E.required "draw_distance" Encode.float drawDistance
    , E.required "force" Encode.float force
    , E.required "measure_id" Measure.encodeId measureId
    ]

