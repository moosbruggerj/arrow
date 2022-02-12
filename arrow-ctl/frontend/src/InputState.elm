module InputState exposing (InputState(..), classList, stringValue, update, toMaybe, helpMessage)

import Html exposing (Html, p, text)
import Html.Attributes as Attr

type InputState a
    = Empty
    | Validated a
    | Error { value: String, error: String }
    | Warning { value: a, warning: String }

classList: InputState a -> List (String, Bool)
classList state =
    case state of
        Empty ->
            []

        Validated _ ->
            [("is-success", True)]

        Error _ ->
            [("is-danger", True)]

        Warning _ ->
            [("has-text-warning-dark", True)]


stringValue: InputState a -> (a -> String) -> String
stringValue state toStr =
    case state of
        Empty ->
            ""

        Validated value ->
            value
                |> toStr

        Error {value, error} ->
            value

        Warning {value, warning} ->
            value
                |> toStr

toMaybe : InputState a -> Maybe a
toMaybe state = 
    case state of
        Validated value ->
            Just value

        Warning { value } ->
            Just value

        _ ->
            Nothing

update: InputState a -> (a -> a) -> InputState a
update state up =
    case state of
        Empty ->
            Empty

        Validated value ->
            Validated (up value)

        Error err ->
            Error err

        Warning { value, warning } ->
            Warning { value = up value, warning = warning }

helpMessage: InputState a -> Html msg
helpMessage state =
    let
        (class, message) =
            case state of
                Empty ->
                    (Nothing, "\u{00A0}")

                Validated _ ->
                    (Nothing, "\u{00A0}")

                Error {value, error} ->
                    (Just "is-danger", error)

                Warning {value, warning} ->
                    (Just "has-text-warning-dark", warning)

        toTuple =
            Maybe.map (\cl -> (cl, True))
                >> Maybe.withDefault ("", False)
    in
    p [ Attr.classList [ ("help", True), ("is-medium", True), toTuple class ] ] [ text message ]
