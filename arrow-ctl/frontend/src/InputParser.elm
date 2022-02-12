module InputParser exposing (length, required, float, force)

import Limits exposing (Limits)
import InputState exposing (InputState)
import Translations.Error as TError
import I18Next as I18N
import Units.Length as Length exposing (Length)
import Units.LengthUnit as LengthUnit exposing (LengthUnit)
import Units.Force as Force exposing (Force)
import Units.ForceUnit as ForceUnit exposing (ForceUnit)

required: String -> I18N.Translations -> InputState String
required input translations =
    if input == "" then
        InputState.Error { value = input, error = TError.required translations }
    else
        InputState.Validated input

float: String -> Limits Float -> I18N.Translations -> InputState Float
float input limits translations =
    let
        value = String.toFloat input
    in
    case value of
        Just val ->
            Limits.check val limits (<) String.fromFloat translations

        Nothing ->
            InputState.Error { value = input, error = TError.numberRequired translations }

force: String -> ForceUnit -> Limits Force -> I18N.Translations -> InputState Force
force input unit limits translations =
    quantity
        input
        unit 
        limits
        (numericQuantity Force.fromParts)
        Force.less
        Force.toString
        translations

length: String -> LengthUnit -> Limits Length -> I18N.Translations -> InputState Length
length input unit limits translations =
    quantity
        input
        unit 
        limits
        (numericQuantity Length.fromParts)
        Length.less
        Length.toString
        translations

numericQuantity: (Float -> u -> a) -> String -> u -> Maybe a
numericQuantity toQuantity input unit =
    let
        numeric = String.toFloat input
        to = \un v -> toQuantity v un
    in
    Maybe.map (to unit) numeric

quantity: String -> u -> Limits a -> (String -> u -> Maybe a) -> (a -> a -> Bool) -> (a -> String) -> I18N.Translations -> InputState a
quantity input unit limits toQuantity less toString translations =
    let
        value = toQuantity input unit
    in
    case value of
        Just val ->
            Limits.check val limits less toString translations

        Nothing ->
            InputState.Error { value = input, error = TError.numberRequired translations }

