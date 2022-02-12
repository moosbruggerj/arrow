module InputFields exposing (unitField, lengthField, textField, numberField, forceField)

import InputState exposing (InputState)
import Html exposing (Html, div, span, select, input, label, text, option)
import Html.Attributes as Attr exposing (class, classList, type_)
import Html.Events exposing (onInput)
import Units.Length as Length exposing (Length)
import Units.LengthUnit as LengthUnit exposing (LengthUnit)
import Units.Force as Force exposing (Force)
import Units.ForceUnit as ForceUnit exposing (ForceUnit)

lengthField: String -> InputState Length -> LengthUnit -> { toValueMsg: (String -> msg), toUnitMsg: (String -> msg)} -> Html msg
lengthField label state unit { toValueMsg, toUnitMsg } =
    unitField
        label
        state
        (lengthUnitOptions unit)
        (lengthValue unit)
        toValueMsg
        toUnitMsg

forceField: String -> InputState Force -> ForceUnit -> { toValueMsg: (String -> msg), toUnitMsg: (String -> msg)} -> Html msg
forceField label state unit { toValueMsg, toUnitMsg } =
    unitField
        label
        state
        (forceUnitOptions unit)
        (forceValue unit)
        toValueMsg
        toUnitMsg

numberField: String -> InputState Float -> (String -> msg) -> Html msg
numberField label state toMsg =
    div [ class "field" ]
        [ Html.label [ class "label", class "is-medium" ] [ text label ]
        , div [ class "control" ]
            [ input 
                [ class "input"
                , class "is-medium"
                , classList (InputState.classList state)
                , type_ "number"
                , Attr.value (InputState.stringValue state String.fromFloat)
                , onInput toMsg ] []
            ]
        , InputState.helpMessage state
        ]

textField: String -> InputState String -> (String -> msg) -> Html msg
textField label state toMsg =
    div [ class "field" ]
        [ Html.label [ class "label", class "is-medium" ] [ text label ]
        , div [ class "control" ]
            [ input 
                [ class "input"
                , class "is-medium"
                , classList (InputState.classList state)
                , type_ "text"
                , Attr.value (InputState.stringValue state identity)
                , onInput toMsg ] []
            ]
        , InputState.helpMessage state
        ]

lengthValue: LengthUnit -> InputState Length -> String
lengthValue unit state =
    InputState.stringValue state (Length.to unit >> Length.toString)

forceValue: ForceUnit -> InputState Force -> String
forceValue unit state =
    InputState.stringValue state (Force.to unit >> Force.toString)

unitField: String -> InputState a -> List (Html msg) -> (InputState a -> String) -> (String -> msg) -> (String -> msg)  -> (Html msg)
unitField label state unitOptions toStr toValueMsg toUnitMsg =
    div [ class "field"]
        [ Html.label [ class "label", class "is-medium" ] [ text label ]
        , div [ class "field", class "has-addons" ]
            [ div [ class "control", class "is-expanded" ]
                [ input 
                    [ class "input"
                    , class "is-medium"
                    , classList (InputState.classList state)
                    , type_ "number"
                    , onInput toValueMsg
                    , Attr.value (toStr state)
                    ] []
                ]
            , div [ class "control" ]
                [ span 
                    [ class "select"
                    , class "is-medium"
                    ]
                    [ select [ onInput toUnitMsg ] (unitOptions)
                    ]
                ]
            ]
        , InputState.helpMessage state
        ]

forceUnitOptions: ForceUnit -> List (Html msg)
forceUnitOptions selected =
    List.map (forceUnitOption selected) ForceUnit.allUnits

forceUnitOption: ForceUnit -> ForceUnit -> Html msg
forceUnitOption selected unit =
    let
        unitString = ForceUnit.toString unit
    in
    option [ Attr.value unitString, Attr.selected (unit == selected) ] [ text unitString ]

lengthUnitOptions: LengthUnit -> List (Html msg)
lengthUnitOptions selected =
    List.map (lengthUnitOption selected) LengthUnit.allUnits

lengthUnitOption: LengthUnit -> LengthUnit -> Html msg
lengthUnitOption selected unit =
    let
        unitString = LengthUnit.toString unit
    in
    option [ Attr.value unitString, Attr.selected (unit == selected) ] [ text unitString ]
