module Route exposing (Route(..), fromUrl, href)

import Html exposing (Attribute)
import Html.Attributes as Attr
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s, string, int)
import Models.Bow as Bow

type Route
    = Home
    | Settings
    | NewMeasurement
    | MeasurementParameters Bow.Id

bowId =
    Parser.custom "BOW_ID" (String.toInt >> (Maybe.map Bow.idFromInt))

parser: Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Home Parser.top
        , Parser.map Settings (s "settings")
        , Parser.map NewMeasurement (s "measurement" </> s "new")
        , Parser.map MeasurementParameters (s "measurement" </> bowId)
        ]

fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser  url

href : Route -> Attribute msg
href route =
    Attr.href (routeToString route)

routeToString : Route -> String
routeToString page =
    "/" ++ String.join "/" (routeToPieces page)


routeToPieces : Route -> List String
routeToPieces page =
    case page of
        Home ->
            []

        Settings ->
            [ "settings" ]

        NewMeasurement ->
            [ "measurement", "new" ]

        MeasurementParameters id ->
            [ "measurement", Bow.idToString id ]
