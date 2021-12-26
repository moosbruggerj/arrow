module Message.Request exposing ( Request(..), encode )

import Json.Encode as Encode
import Models.Bow as Bow exposing (Bow)
import Models.Arrow as Arrow exposing (Arrow)
import Models.MeasureSeries as MeasureSeries exposing (MeasureSeries)
import Models.Measure as Measure exposing (Measure)
import Models.MachineCommand as MachineCommand exposing (MachineCommand)

type Request
    = ListBows {}
    | ListMeasureSeries { bowId: Bow.Id }
    | ListArrows { bowId: Bow.Id }
    | ListMeasures { seriesId: MeasureSeries.Id }
    | ListMeasurePoints { measureId: Measure.Id }
    | AddBow Bow
    | AddArrow Arrow
    | NewMeasureSeries MeasureSeries
    | StartMeasure Measure
    | Command MachineCommand

encode : Request -> Encode.Value
encode request =
  Encode.object [ ( "request", encodeRequest request ) ]

encodeRequest: Request -> Encode.Value
encodeRequest request =
  Encode.object
    <| case request of
      ListBows {} ->
        [ ( "listbows", Encode.object [] ) ]

      ListMeasureSeries { bowId } ->
        [ ( "listmeasureseries", Encode.object [ ("bow_id", Bow.encodeId bowId ) ] ) ]

      ListArrows { bowId } ->
        [ ( "listarrows", Encode.object [ ("bow_id", Bow.encodeId bowId ) ] ) ]

      ListMeasures { seriesId } ->
        [ ( "listmeasures", Encode.object [ ("series_id", MeasureSeries.encodeId seriesId ) ] ) ]

      ListMeasurePoints { measureId } ->
        [ ( "listmeasurepoints", Encode.object [ ("measure_id", Measure.encodeId measureId ) ] ) ]

      AddBow bow ->
        [ ( "addbow", Bow.encode bow ) ]

      AddArrow arrow ->
        [ ( "addarrow", Arrow.encode arrow ) ]

      NewMeasureSeries series ->
        [ ( "newmeasureseries", MeasureSeries.encode series ) ]

      StartMeasure measure ->
        [ ( "startmeasure", Measure.encode measure ) ]

      Command cmd ->
        [ ( "command", MachineCommand.encode cmd ) ]
