module Page.Measurement.Parameters exposing (Msg, Model, init, view, update, toSession, updateSession, subscriptions)

import Session exposing (Session)
import Html exposing (Html, text, div, span)
import Html.Attributes as Attr exposing (class, type_, classList)
import Html.Events exposing (onInput)
import Message exposing (Message)
import Translations.Parameters as TParameters
import InputState exposing (InputState)
import InputFields
import Units.Force as Force exposing (Force)
import Units.ForceUnit as ForceUnit exposing (ForceUnit)
import Units.Length as Length exposing (Length)
import Units.LengthUnit as LengthUnit exposing (LengthUnit)
import Limits exposing (Limits)
import InputParser

type Msg
    = GotMessage Session Message
    | SetName String
    | SetInterval String
    | SetRestHeight String
    | SetDrawDistance String
    | SetDrawForce String
    | SetRestHeightUnit String
    | SetDrawDistanceUnit String
    | SetDrawForceUnit String

drawForceLimits: Limits Force
drawForceLimits =
    { min = Just (Force.fromParts 0 ForceUnit.Newton)
    , max = Nothing
    , warningMin = Just (Force.fromParts 10 ForceUnit.Newton)
    , warningMax = Just (Force.fromParts 80 ForceUnit.Pound)
    }

drawDistanceLimits: Length -> Limits Length
drawDistanceLimits bowMaxDrawDistance =
    { min = Just (Length.fromParts 0 LengthUnit.Meter)
    , max = Just bowMaxDrawDistance
    , warningMin = Just (Length.fromParts 10 LengthUnit.Centimeter)
    , warningMax = Nothing
    }

intervalLimits: Limits Float
intervalLimits =
    { min = Just 0
    , max = Nothing
    , warningMin = Just 10
    , warningMax = Just 3000
    }

type alias Config =
    { restHeightUnit: LengthUnit
    , drawDistanceUnit: LengthUnit
    , drawForceUnit: ForceUnit
    }

type alias Model = 
    { session: Session
    , name: InputState String
    , interval: InputState Float
    , restHeight: InputState Length
    , drawDistance: InputState Length
    , drawForce: InputState Force
    , config: Config
    }


init: Session -> (Model, Cmd Msg)
init session =
    ( { session = session
    , name = InputState.Empty
    , interval = InputState.Validated 10
    , restHeight = InputState.Empty
    , drawDistance = InputState.Empty
    , drawForce = InputState.Empty
    , config = 
        { restHeightUnit = LengthUnit.Inch
        , drawDistanceUnit = LengthUnit.Inch
        , drawForceUnit = ForceUnit.Pound
        }
    }
    , Cmd.none
    )

view : Model -> { title: String, content: Html Msg, headerElement: Maybe (Html Msg) }
view model =
    { title = "Measurement Properties"
    , content = viewForm model
    , headerElement = Nothing
    }

viewForm: Model -> Html Msg
viewForm model =
    let
        translations = model.session.translations
    in
    div []
        [ div [ class "columns" ]
            [ div [ class "column", class "py-0" ]
                [ InputFields.textField
                    (TParameters.name translations)
                    model.name
                    SetName
                ]
            , div [ class "column", class "py-0", class "is-1" ] []
            , div [ class "column", class "py-0" ]
                [ div [ class "field"]
                    [ Html.label [ class "label", class "is-medium" ] [ text (TParameters.interval translations) ]
                    , div [ class "field", class "has-addons" ]
                        [ div [ class "control", class "is-expanded" ]
                            [ Html.input 
                                [ class "input"
                                , class "is-medium"
                                , classList (InputState.classList model.interval)
                                , type_ "number"
                                , onInput SetInterval
                                , Attr.value (InputState.stringValue model.interval String.fromFloat)
                                ] []
                            ]
                        , div [ class "control" ]
                            [ span
                                [ class "button"
                                , class "is-medium"
                                , Attr.style "cursor" "auto"
                                --, class "is-static"
                                ]
                                    [ text "ms" ]

                                {-
                                [ Html.select [ Attr.disabled True ] 
                                    [ Html.option [ Attr.value "ms", Attr.selected True ] [ text "ms" ] ]
                                ]
                                -}
                            ]
                        ]
                    , InputState.helpMessage model.interval
                    ]
                ]
            ]
        , div [ class "columns" ]
            [ div [ class "column", class "py-0" ]
                [ InputFields.lengthField
                    (TParameters.restHeight translations)
                    model.restHeight
                    model.config.restHeightUnit
                    { toValueMsg = SetRestHeight
                    , toUnitMsg = SetRestHeightUnit
                    }
                ]
            , div [ class "column", class "py-0", class "is-1" ] []
            , div [ class "column", class "py-0" ] []
            ]
        , div [ class "columns" ]
            [ div [ class "column", class "py-0" ]
                [ InputFields.lengthField
                    (TParameters.drawDistance translations)
                    model.drawDistance
                    model.config.drawDistanceUnit
                    { toValueMsg = SetDrawDistance
                    , toUnitMsg = SetDrawDistanceUnit
                    }
                ]
            , div 
                [ class "column"
                , class "py-0"
                , class "is-1"
                , class "is-flex"
                , class "is-justify-content-center"
                , class "is-align-items-center"
                ]
                [ text (TParameters.or translations)]
            , div [ class "column", class "py-0" ]
                [ InputFields.forceField
                    (TParameters.drawForce translations)
                    model.drawForce
                    model.config.drawForceUnit
                    { toValueMsg = SetDrawForce
                    , toUnitMsg = SetDrawForceUnit
                    }
                ]
            ]
        ]

update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    let
        translations = model.session.translations
    in
    case message of
        GotMessage session _ ->
            (updateSession session model, Cmd.none)

        SetName input ->
            ({ model | name = 
                InputParser.required 
                    input 
                    translations 
            }
            , Cmd.none)

        SetInterval input ->
            ({ model | interval = 
                InputParser.float 
                    input 
                    intervalLimits 
                    translations 
            }
            , Cmd.none)

        SetRestHeight input ->
            ({ model | restHeight = 
                InputParser.length 
                    input 
                    model.config.restHeightUnit 
                    Limits.none -- TODO: fix limits
                    translations 
            }
            , Cmd.none)

        SetDrawDistance input ->
            ({ model | drawDistance = 
                InputParser.length 
                    input 
                    model.config.drawDistanceUnit 
                    Limits.none -- TODO: fix limits
                    translations 
            }
            , Cmd.none)

        SetDrawForce input ->
            ({ model | drawForce = 
                InputParser.force 
                    input 
                    model.config.drawForceUnit 
                    drawForceLimits 
                    translations 
            }
            , Cmd.none)

        SetRestHeightUnit unitStr ->
            let
                parsedUnit = LengthUnit.fromString unitStr
            in
            case parsedUnit of
                Err _ ->
                    ( model, Cmd.none )

                Ok unit ->
                    let
                        oldConfig = model.config
                    in
                    ( { model | config = { oldConfig | restHeightUnit = unit }
                        , restHeight = updateLength model.restHeight unit }, Cmd.none )

        SetDrawDistanceUnit unitStr ->
            let
                parsedUnit = LengthUnit.fromString unitStr
            in
            case parsedUnit of
                Err _ ->
                    ( model, Cmd.none )

                Ok unit ->
                    let
                        oldConfig = model.config
                    in
                    ( { model | config = { oldConfig | drawDistanceUnit = unit }
                        , drawDistance = updateLength model.drawDistance unit }, Cmd.none )

        SetDrawForceUnit unitStr ->
            let
                parsedUnit = ForceUnit.fromString unitStr
            in
            case parsedUnit of
                Err _ ->
                    ( model, Cmd.none )

                Ok unit ->
                    let
                        oldConfig = model.config
                    in
                    ( { model | config = { oldConfig | drawForceUnit = unit }
                        , drawForce = updateForce model.drawForce unit }, Cmd.none )


toSession: Model -> Session
toSession model =
    model.session

updateSession: Session -> Model -> Model
updateSession session model =
    { model | session = session }

subscriptions: Model -> Sub Msg
subscriptions model =
    let
        session = toSession model
    in
    Session.subscriptions GotMessage session

updateLength: InputState Length -> LengthUnit -> InputState Length
updateLength state unit =
    InputState.update state (Length.to unit)

updateForce: InputState Force -> ForceUnit -> InputState Force
updateForce state unit =
    InputState.update state (Force.to unit)
