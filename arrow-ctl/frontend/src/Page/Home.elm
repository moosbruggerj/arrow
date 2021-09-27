module Page.Home exposing (Msg, Model, init, view, update, toSession, updateSession)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Session exposing (Session)

type alias Model =
    { session: Session }

type Msg
    = None

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
    , content = text "Home"
    , headerElement = Nothing
    }

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    (model, Cmd.none)

toSession: Model -> Session
toSession model =
    model.session

updateSession: Session -> Model -> Model
updateSession session model =
    { model | session = session }
