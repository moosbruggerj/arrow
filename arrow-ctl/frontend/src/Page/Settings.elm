module Page.Settings exposing (init, view, update, fetchTranslations, Model, Msg(..), updateSession, toSession, updateGlobal)
import I18Next as I18N
import Http
import Html exposing (..)
import Notification exposing (Notification)
import Session exposing (Session)

type alias Model =
    { session: Session
    }

type GlobalMsg
    = LanguageDataReceived String (Result Http.Error I18N.Translations)

type LocalMsg
    = LanguageChanged String

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
    , content = text "Settings"
    , headerElement = Nothing
    }

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

toSession: Model -> Session
toSession model =
    model.session

updateSession: Session -> Model -> Model
updateSession session model =
    { model | session = session }
