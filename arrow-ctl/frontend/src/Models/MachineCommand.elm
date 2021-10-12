module Models.MachineCommand exposing ( MachineCommand(..), encode )

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode

type MachineCommand
    = Calibrate
    | Reset
    | Restart
    | Shutdown

encode: MachineCommand -> Encode.Value
encode command =
  Encode.string
    <| case command of
      Calibrate ->
        "calibrate"

      Reset ->
        "reset"

      Restart ->
        "restart"

      Shutdown ->
        "shutdown"

