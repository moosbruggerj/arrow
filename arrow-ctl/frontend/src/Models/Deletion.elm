module Models.Deletion exposing(Deletion(..), decoder, typeToString)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Decode as MD
import Json.Encode as Encode
import Models.Encode as E
import Models.Bow as Bow exposing (Bow)
import Models.Arrow as Arrow exposing (Arrow)
import Models.MeasureSeries as MeasureSeries exposing (MeasureSeries)
import Models.Measure as Measure exposing (Measure)
import Models.MeasurePoint as MeasurePoint exposing (MeasurePoint)

type Deletion
    = BowDeletion Bow.Id
    | MeasureSeriesDeletion MeasureSeries.Id
    | ArrowDeletion Arrow.Id
    | MeasureDeletion Measure.Id
    | MeasurePointDeletion MeasurePoint.Id

decoder: Decoder Deletion
decoder =
  Decode.keyValuePairs Decode.value
    |> Decode.andThen (\value ->
      case value of
        ((key, _) :: []) -> -- list must have exactly one tuple element
          Decode.field key
            <| case key of
              "bow" ->
                Decode.map BowDeletion Bow.idDecoder

              "measureseries" ->
                Decode.map MeasureSeriesDeletion MeasureSeries.idDecoder

              "arrow" ->
                Decode.map ArrowDeletion Arrow.idDecoder

              "measure" ->
                Decode.map MeasureDeletion Measure.idDecoder

              "measurepoint" ->
                Decode.map MeasurePointDeletion MeasurePoint.idDecoder

              _ ->
                Decode.fail "unknown message type"
        _ ->
          Decode.fail "unknown message format"
   )

typeToString: Deletion -> String
typeToString deletion =
    case deletion of
        BowDeletion _ ->
            "Bow"

        MeasureSeriesDeletion _ ->
            "Measure Series"

        ArrowDeletion _ ->
            "Arrow"

        MeasureDeletion _ ->
            "Measure"

        MeasurePointDeletion _ ->
            "Measure Point"
