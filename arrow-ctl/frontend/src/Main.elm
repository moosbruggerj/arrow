module Main exposing (..)

import Browser
import Browser.Navigation as Nav
import Html exposing (..)
import Html.Attributes exposing (..)
import Page
import Url
import Json.Encode
import Json.Decode
import I18Next as I18N
import Notification exposing (Notification)
import Page.Settings as Settings
import Page.Home as Home
import Page.Blank
import Page.NotFound
import Route exposing (Route)
import Session exposing (Session)
import Message exposing (Message)



-- optimize screen for 7" with 16:9 aspect ratio
-- MAIN


main : Program () Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }



-- MODEL


type Model
    = NotFound Session
    | Redirect Session
    | Home Home.Model
    | Settings Settings.Model


init : () -> Url.Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        lang = "en"
        ( model, cmd) =
            changeRouteTo (Route.fromUrl url) ( Redirect (Session.initSession key) )
    in
    ( model
    , Cmd.batch [ Cmd.map SettingsMsg (Settings.fetchTranslations lang), cmd ]
    )
    --(Model key url Page.initModel Home (I18N.fromTree []) lang, Cmd.map SettingsMsg (Settings.fetchTranslations lang))



-- UPDATE


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | PageMsg Page.Msg
    | SettingsMsg Settings.Msg
    | HomeMsg Home.Msg
    | GotMessage Session Message


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case (msg, model) of
        (LinkClicked urlRequest, _) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model, Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url) )

                Browser.External href ->
                    ( model, Nav.load href )

        (UrlChanged url, _) ->
            changeRouteTo (Route.fromUrl url) model

        (PageMsg pageMsg, _) ->
            Page.update pageMsg (toSession model)
                |> updateWithSession PageMsg model

        (SettingsMsg (Settings.Global settingsMsg), _) ->
            Settings.updateGlobal settingsMsg (toSession model)
                |> updateWithSession SettingsMsg model

        (SettingsMsg (Settings.Local settingsMsg), Settings settings) ->
            Settings.update settingsMsg settings
                |> updateWith Settings SettingsMsg

        (HomeMsg homeMsg, Home home) ->
            Home.update homeMsg home
                |> updateWith Home HomeMsg

        (GotMessage session message, NotFound _) ->
            (updateSession model session, Cmd.none)

        (GotMessage session message, Redirect _) ->
            (updateSession model session, Cmd.none)

        (_, _) ->
            -- arrived at the wrong page, ignore
            (model, Cmd.none)


updateWith: (subModel -> Model) -> (subMsg -> Msg) -> (subModel, Cmd subMsg) -> (Model, Cmd Msg)
updateWith toModel toMsg (subModel, subCmd) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )

updateWithSession:  (subMsg -> Msg) -> Model -> (Session, Cmd subMsg) -> (Model, Cmd Msg)
updateWithSession toMsg model (session, subCmd) =
    ( updateSession model session
    , Cmd.map toMsg subCmd
    )

updateSession: Model -> Session -> Model
updateSession model session =
    case model of
        NotFound _ ->
            NotFound session

        Redirect _ ->
            Redirect session

        Home home ->
            Home (Home.updateSession session home)

        Settings settings ->
            Settings (Settings.updateSession session settings)


toSession: Model -> Session
toSession model =
    case model of
        NotFound session ->
            session

        Redirect session ->
            session

        Home home ->
            Home.toSession home

        Settings settings ->
            Settings.toSession settings

changeRouteTo: Maybe Route -> Model -> (Model, Cmd Msg)
changeRouteTo route model =
    let
        session = toSession model
    in
    case route of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just Route.Home ->
            Home.init session
                |> updateWith Home HomeMsg

        Just Route.Settings ->
            Settings.init session
                |> updateWith Settings SettingsMsg

        Just Route.NewMeasurement ->
            ( NotFound session, Cmd.none ) --TODO


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        NotFound session ->
            Session.subscriptions GotMessage session

        Redirect session ->
            Session.subscriptions GotMessage session

        Home home ->
            Sub.map HomeMsg (Home.subscriptions home)

        Settings settings ->
            Sub.map SettingsMsg (Settings.subscriptions settings)


-- VIEW

view : Model -> Browser.Document Msg
view model =
    let
        session = toSession model
        viewPage = Page.view session PageMsg
    in
    case model of
        NotFound _ ->
            Page.NotFound.view
                |> viewPage

        Redirect _ ->
            Page.Blank.view
                |> viewPage

        Home home ->
            Home.view home
                |> mapDocumentType HomeMsg
                |> viewPage

        Settings settings ->
            Settings.view settings
                |> mapDocumentType SettingsMsg
                |> viewPage

type alias PageDocument a =
    { title: String
    , content: Html a
    , headerElement: Maybe (Html a)
    }

mapDocumentType : (msg -> Msg) -> PageDocument msg -> PageDocument Msg
mapDocumentType toMsg {title, content, headerElement} =
    { title = title
    , content = Html.map toMsg content
    , headerElement = Maybe.map (Html.map toMsg) headerElement
    }
