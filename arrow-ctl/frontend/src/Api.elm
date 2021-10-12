port module Api exposing (message)

import Json.Encode as Encode
import Json.Decode as Decode
import Message exposing (Message)

port sendMessage: Encode.Value -> Cmd msg
port onMessageReceived: (Decode.Value -> msg) -> Sub msg

type Msg
    = GotMessage Message

message: (Message -> msg) -> Sub msg
message toMsg =
    onMessageReceived (\value -> toMsg (parse value))

parse: Decode.Value -> Message
parse value =
  Decode.decodeValue Message.decoder value
    |> errToMessage

errToMessage: Result Decode.Error Message -> Message
errToMessage result =
  case result of
    Ok msg ->
      msg

    Err err ->
      {msg = Message.Error (Decode.errorToString err), isResponse = False }


