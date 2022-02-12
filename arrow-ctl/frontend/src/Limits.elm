module Limits exposing (Limits, check, none)

import InputState exposing (InputState)
import I18Next as I18N
import Translations.Error as TError
import Translations.Warning as TWarning

type alias Limits a =
    { min: Maybe a
    , max: Maybe a
    , warningMin: Maybe a
    , warningMax: Maybe a
    }

none: Limits a
none =
    { min = Nothing
    , max = Nothing
    , warningMin = Nothing
    , warningMax = Nothing
    }

check: a -> Limits a -> (a -> a -> Bool) -> (a -> String) -> I18N.Translations -> InputState a
check value limits isLess toString translations =
    let
        less: a -> Maybe a -> Bool
        less val limit = 
            case limit of
                Nothing ->
                    False

                Just l ->
                    isLess value l

        greater: a -> Maybe a -> Bool
        greater val limit = 
            case limit of
                Nothing ->
                    False

                Just l ->
                    isLess l value

    in
    if less value limits.min then
        InputState.Error { value = toString value, error = TError.tooSmall translations }

    else if greater value limits.max then
        InputState.Error { value = toString value, error = TError.tooBig translations }

    else if less value limits.warningMin then
        InputState.Warning { value = value, warning = TWarning.tooSmall translations }

    else if greater value limits.warningMax then
        InputState.Warning { value = value, warning = TWarning.tooBig translations }

    else
        InputState.Validated value
