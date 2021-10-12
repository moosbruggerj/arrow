module Models.MeasureSeries exposing(Id, MeasureSeries, idDecoder, decoder, encode, encodeId)

import Time
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Decode as MD
import Json.Encode as Encode
import Models.Encode as E
import Models.Bow as Bow

type Id
    = Id Int

type alias MeasureSeries =
  { id: Id
  , name: String
  , restPosition: Float
  , drawDistance: Maybe Float
  , drawForce: Maybe Float
  , time: Time.Posix
  , bowId: Bow.Id
  }

idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

timeParser: Int -> Time.Posix
timeParser time =
  Time.millisToPosix time

timeDecoder: Decoder Time.Posix
timeDecoder =
  Decode.map timeParser Decode.int


decoder: Decoder MeasureSeries
decoder =
  Decode.succeed MeasureSeries
    |> D.required "id" idDecoder
    |> D.required "name" Decode.string
    |> D.required "rest_position" Decode.float
    |> MD.maybe "draw_distance" Decode.float
    |> MD.maybe "draw_force" Decode.float
    |> D.required "time" timeDecoder
    |> D.required "bow_id" Bow.idDecoder

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encodeTime: Time.Posix -> Encode.Value
encodeTime time =
  Encode.int (Time.posixToMillis time)

encode: MeasureSeries -> Encode.Value
encode { id, name, restPosition, drawDistance, drawForce, time, bowId } =
  E.object
    [ E.required "id" encodeId id
    , E.required "name" Encode.string name
    , E.maybe "draw_distance" Encode.float drawDistance
    , E.maybe "draw_force" Encode.float drawForce
    , E.required "time" encodeTime time
    , E.required "bow_id" Bow.encodeId bowId
    ]

