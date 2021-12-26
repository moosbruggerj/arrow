port module Api exposing (message, fetch, get, request)

import Json.Encode as Encode
import Json.Decode as Decode
import Message exposing (Message)
import Message.Request as Request exposing (Request)
import Api.Error
import Api.Endpoint exposing (Endpoint)
import Http

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
      Message.Error (Decode.errorToString err)

fetch: Request -> Cmd msg
fetch req =
  sendMessage (Request.encode req)

get: (Result Api.Error.Error Message -> msg) -> Endpoint -> Cmd msg
get toMsg endpoint =
    Api.Endpoint.request 
        { body = Http.emptyBody
        , toMsg = toMsg
        , headers = []
        , timeout = Nothing
        , url = endpoint
        }

request: (Result Api.Error.Error Message -> msg) -> Endpoint -> Http.Body -> Cmd msg
request toMsg endpoint body =
    Api.Endpoint.request 
        { body = body
        , toMsg = toMsg
        , headers = []
        , timeout = Nothing
        , url = endpoint
        }
