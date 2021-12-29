module Message exposing ( Message(..), decoder, typeToString )

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as D
import Models.Bow as Bow exposing (Bow)
import Models.Arrow as Arrow exposing (Arrow)
import Models.MeasureSeries as MeasureSeries exposing (MeasureSeries)
import Models.Measure as Measure exposing (Measure)
import Models.MeasurePoint as MeasurePoint exposing (MeasurePoint)
import Models.MachineStatus as MachineStatus exposing (MachineStatus)
import Models.Deletion as Deletion exposing (Deletion)

type Message
    = Alive
    | BowList (List Bow)
    | MeasureSeriesList (List MeasureSeries)
    | ArrowList (List Arrow)
    | MeasureList (List Measure)
    | MeasurePointList (List MeasurePoint)
    | Deletion Deletion
    | MachineStatus MachineStatus
    | Error String

decoder: Decoder Message
decoder =
  Decode.keyValuePairs Decode.value
    |> Decode.andThen (\value ->
      case value of
        ((key, _) :: []) -> -- list must have exactly one tuple element
          Decode.field key
            <| case key of
              "alive" ->
                Decode.succeed Alive

              "bowlist" ->
                Decode.map BowList (Decode.list Bow.decoder)

              "measureserieslist" ->
                Decode.map MeasureSeriesList (Decode.list MeasureSeries.decoder)

              "arrowlist" ->
                Decode.map ArrowList (Decode.list Arrow.decoder)

              "measurelist" ->
                Decode.map MeasureList (Decode.list Measure.decoder)

              "measurepointlist" ->
                Decode.map MeasurePointList (Decode.list MeasurePoint.decoder)

              "status" ->
                Decode.map MachineStatus MachineStatus.decoder

              "error" ->
                Decode.map Error Decode.string

              "deletion" ->
                Decode.map Deletion Deletion.decoder

              _ ->
                Decode.fail "unknown message type"
        _ ->
          Decode.fail "unknown message format"
   )

typeToString: Message -> String
typeToString msg =
    case msg of
        Alive ->
            "Alive"

        BowList _ ->
            "Bow List"

        MeasureSeriesList _ ->
            "Measure Series List"

        ArrowList _ ->
            "Arrow List"

        MeasureList _ ->
            "Measure List"

        MeasurePointList _ ->
            "Measure Point List"

        MachineStatus _ ->
            "Machine Status"

        Deletion _ ->
            "Deletion"

        Error _ ->
            "Error"
