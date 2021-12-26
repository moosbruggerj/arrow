module Api.Endpoint exposing (Endpoint, request, listBows, modifyBow, deleteBow, listArrows, addArrow, listMeasureSeries, addMeasureSeries, listMeasures, listPoints, command, startMeasure)

import Http
import Url.Builder
import Models.Bow as Bow
import Models.MeasureSeries as MeasureSeries
import Models.Measure as Measure
import Api.Error
import Message exposing (Message)
import Json.Decode as D

type Method
    = GET
    | POST
    | DELETE

type Endpoint
    = Endpoint Method String


toString : Method -> String
toString method =
    case method of
        GET -> "GET"
        POST -> "POST"
        DELETE -> "DELETE"

{-| Http.request, except it takes an Endpoint instead of a Url.
-}
request :
    { body : Http.Body
    , toMsg : (Result Api.Error.Error Message -> msg)
    , headers : List Http.Header
    , timeout : Maybe Float
    , url : Endpoint
    }
    -> Cmd msg
request config =
    let
        (method, url) = unwrap config.url
    in
    Http.request
        { body = config.body
        , expect = expectMessage config.toMsg Message.decoder
        , headers = config.headers
        , method = toString method
        , timeout = config.timeout
        , tracker = Nothing
        , url = url
        }


expectMessage : (Result Api.Error.Error Message -> msg) -> D.Decoder a -> Http.Expect msg
expectMessage toMsg decoder =
  Http.expectStringResponse toMsg <|
    \response ->
      case response of
        Http.BadUrl_ url ->
          Err (Api.Error.Http (Http.BadUrl url))

        Http.Timeout_ ->
          Err (Api.Error.Http Http.Timeout)

        Http.NetworkError_ ->
          Err (Api.Error.Http Http.NetworkError)

        Http.BadStatus_ metadata body ->
          case D.decodeString Message.decoder body of
            Ok value ->
                case value of
                    Message.Error str ->
                        Err (Api.Error.Api str)

                    _ ->
                        Err (Api.Error.Http (Http.BadStatus metadata.statusCode))

            Err err ->
              Err (Api.Error.Http (Http.BadBody (D.errorToString err)))

        Http.GoodStatus_ metadata body ->
          case D.decodeString Message.decoder body of
            Ok value ->
              Ok value

            Err err ->
              Err (Api.Error.Http (Http.BadBody (D.errorToString err)))

unwrap : Endpoint -> (Method, String)
unwrap (Endpoint method str) =
    (method, str)

toUrl : Method -> List String -> Endpoint
toUrl method paths =
    Url.Builder.absolute
        ("api" :: paths)
        []
        |> Endpoint method


listBows : Endpoint
listBows =
    toUrl GET [ "bows" ]

modifyBow : Endpoint
modifyBow =
    toUrl POST [ "bow" ]

deleteBow : Bow.Id -> Endpoint
deleteBow id =
    toUrl DELETE [ "bow" , Bow.idToString id ]

listMeasureSeries : Bow.Id -> Endpoint
listMeasureSeries id =
    toUrl GET [ Bow.idToString id, "series" ]

addMeasureSeries : Endpoint
addMeasureSeries =
    toUrl POST [ "series" ]

listArrows : Bow.Id -> Endpoint
listArrows id =
    toUrl GET [ Bow.idToString id, "arrows" ]

addArrow : Endpoint
addArrow =
    toUrl POST [ "arrow" ]

listMeasures : MeasureSeries.Id -> Endpoint
listMeasures id =
    toUrl GET [ MeasureSeries.idToString id, "measures" ]

startMeasure : Endpoint
startMeasure =
    toUrl POST [ "measure", "start" ]

listPoints : Measure.Id -> Endpoint
listPoints id =
    toUrl GET [ Measure.idToString id, "points" ]

command : Endpoint
command =
    toUrl POST [ "command" ]
