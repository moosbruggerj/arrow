module Models.MachineStatus exposing ( MachineStatus(..), decoder )

import Json.Decode as Decode exposing (Decoder)

type MachineStatus
    = Pause
    | Shooting
    | Error

decoder: Decoder MachineStatus
decoder =
  Decode.string |>
    Decode.andThen (\status -> case status of
      "pause" ->
        Decode.succeed Pause

      "shooting" ->
        Decode.succeed Shooting 

      "error" ->
        Decode.succeed Error
        
      _ ->
        Decode.fail "unknown machine status" )

