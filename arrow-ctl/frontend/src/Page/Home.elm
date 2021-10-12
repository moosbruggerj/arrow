module Page.Home exposing (Msg, Model, init, view, update, toSession, updateSession, subscriptions)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Session exposing (Session)
import Translations.Home as THome
import Route exposing (Route)
import Message exposing (Message)

type alias Model =
    { session: Session }

type Msg
    = None
    | GotMessage Session Message

-- INIT

init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }
    , Cmd.none
    )

-- VIEW
view : Model -> { title: String, content: Html Msg, headerElement: Maybe (Html Msg) }
view model =
    { title = "Home"
    , content = viewButtons model
    , headerElement = Nothing
    }

viewButtons: Model -> Html Msg
viewButtons model =
    let
        translations = 
            model.session.translations
    in
    div [ class "is-flex", class "is-flex-direction-row", class "is-justify-content-space-around" ]
        [ div [ class "is-flex", class "is-flex-direction-column", class "is-align-content-space-around"]
            [ viewButton Route.NewMeasurement [ span [ class "fas", class "fa-plus-circle", class "mr-2" ] [], text (THome.newMeasurement translations) ]
            , viewButton Route.Home [ span [ class "fas", class "fa-crosshairs", class "mr-2" ] [], text (THome.calibration translations) ] -- TODO: Route
            ]
        , div [ class "is-flex", class "is-flex-direction-column", class "is-align-content-space-around"]
            [ viewButton Route.Home [ span [ class "fas", class "fa-tasks", class "mr-2" ] [], text (THome.manageMeasurements translations) ] -- TODO: Route
            , viewButton Route.Home [ span [ class "fas", class "fa-question-circle", class "mr-2"] [], text ( THome.help translations) ] -- TODO: Help
            ] 
        ]

viewButton: Route -> List (Html Msg) -> Html Msg
viewButton route content =
    div [ class "is-justify-content-center", style "width" "40vw", style "height" "20vh", class "my-5" ]
        [ a [ class "button", class "is-large", class "is-outline", class "is-fullwidth", class "is-light", class "has-text-weight-bold", style "height" "100%", Route.href route ] content ]

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        None ->
            (model, Cmd.none)

        GotMessage session _ ->
            ( { model | session = session }, Cmd.none )

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
