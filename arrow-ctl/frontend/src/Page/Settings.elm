module Page.Settings exposing (init, view, update, fetchTranslations, Model, Msg(..), updateSession, toSession, updateGlobal, subscriptions)
import I18Next as I18N
import Http
import Html exposing (..)
import Html.Attributes exposing (class, alt, src, classList)
import Html.Events exposing (onClick)
import Notification exposing (Notification)
import Session exposing (Session)
import Message exposing (Message)
import Translations.Settings.Labels as TSLabels

type alias Model =
    { session: Session
    }

type GlobalMsg
    = LanguageDataReceived String (Result Http.Error I18N.Translations)

type LocalMsg
    = LanguageChanged String
    | GotMessage Session Message

type Msg
    = Global GlobalMsg
    | Local LocalMsg

translationUrl: String -> String
translationUrl lang = 
    "/static/translations/translations." ++ lang ++ ".json"

init: Session -> (Model, Cmd Msg)
init session =
    ({ session = session }
    , Cmd.none)

view : Model -> { title: String, content: Html Msg, headerElement: Maybe (Html Msg) }
view model =
    { title = "Settings"
    , content = viewSettings model
    , headerElement = Nothing
    }

viewSettings : Model -> Html Msg
viewSettings model =
    viewField (TSLabels.language model.session.translations) (languageButtons model)

viewField : String -> Html Msg -> Html Msg
viewField name form =
    div [ class "field", class "is-horizontal" ] 
        [ div [ class "field-label", class "is-normal" ]
            [ label [ class "label" ] [ text name ] ]
        , div [ class "field-body" ]
            [ div [ class "field" ] [ form ] ]
        ]

languageButtons : Model -> Html Msg
languageButtons model =
    div [ class "buttons" ] 
        [ languageButton model "en" "English"
        , languageButton model "de" "Deutsch"
        ]

languageButton : Model -> String -> String -> Html Msg
languageButton model lang altText =
    img
        [ class "control"
        , class "button"
        , classList [ ("is-focused", model.session.language == lang) ]
        , src ("/static/images/lang-" ++ lang ++ ".png")
        , alt altText
        , class "p-1"
        , onClick (Local (LanguageChanged lang))
        ]
        [ ]
        {--
    button
        [ class "control"
        , class "button"
        , classList [ ("is-active", model.session.language == lang) ]
        ]
        [ span [ class "icon" ]
            [ img [ src ("/static/images/lang-" ++ lang ++ ".png"), alt altText ] [] ]
        ]
        --}
fetchTranslations: String -> Cmd Msg
fetchTranslations lang =
    Http.get
        { url = translationUrl lang
        , expect = Http.expectJson (constructLanguageReceivedMsg lang) I18N.translationsDecoder
        }

constructLanguageReceivedMsg: String -> (Result Http.Error I18N.Translations) -> Msg
constructLanguageReceivedMsg lang translation =
    Global (LanguageDataReceived lang translation)

updateGlobal: GlobalMsg -> Session -> (Session, Cmd Msg)
updateGlobal msg session =
    case msg of
        LanguageDataReceived lang (Ok data) ->
            ( Session.changeLanguage session lang data
            , Cmd.none
            )

        LanguageDataReceived lang (Err err) ->
            ( Session.addNotifications session 
                [ Notification.toNotification {text = "Could not change language to '" ++ lang ++ "'.", nType = "error" } ]
            , Cmd.none)

update: LocalMsg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        LanguageChanged lang ->
            ( model, fetchTranslations lang)

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
        toMsg updated msg = 
          Local (GotMessage updated msg)
    in
    Session.subscriptions toMsg session
