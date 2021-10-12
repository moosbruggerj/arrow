module Models.Measure exposing(Id, Measure, idDecoder, decoder, encode, encodeId)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Decode as MD
import Json.Encode as Encode
import Models.Encode as E
import Models.Arrow as Arrow
import Models.MeasureSeries as MeasureSeries

type Id
    = Id Int

type alias Measure =
  { id: Id
  , measureInterval: Float
  , measureSeriesId: MeasureSeries.Id
  , arrowId: Arrow.Id
  }

idDecoder: Decoder Id
idDecoder =
  Decode.map Id Decode.int

decoder: Decoder Measure
decoder =
  Decode.succeed Measure
    |> D.required "id" idDecoder
    |> D.required "measure_interval" Decode.float
    |> D.required "measure_series_id" MeasureSeries.idDecoder
    |> D.required "arrow_id" Arrow.idDecoder

encodeId: Id -> Encode.Value
encodeId (Id id) =
  Encode.int id

encode: Measure -> Encode.Value
encode { id, measureInterval, measureSeriesId, arrowId } =
  E.object
    [ E.required "id" encodeId id
    , E.required "measure_interval" Encode.float measureInterval
    , E.required "measure_series_id" MeasureSeries.encodeId measureSeriesId
    , E.required "arrow_id" Arrow.encodeId arrowId
    ]

