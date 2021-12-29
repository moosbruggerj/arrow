module Session exposing (Session, initSession, addNotifications, IdentifiedNotification, NotificationId, changeLanguage, navKey, toIdString, subscriptions, addApiError )

import I18Next as I18N
import Browser.Navigation as Nav
import Notification exposing (Notification)
import Message exposing (Message)
import Models.MachineStatus as MachineStatus exposing (MachineStatus)
import Api
import Api.Error
import Http
import Translations.Error as TError

type alias Session =
    { navKey : Nav.Key
    , translations : I18N.Translations
    , language : String
    , notifications : List IdentifiedNotification
    , nextNotificationId : NotificationId
    , settingsVisible: Bool
    , status: MachineStatus
    }

type NotificationId
    = NotificationId Int


type alias IdentifiedNotification =
    { id : NotificationId
    , text : String
    , nType : Notification.NotificationType
    }

-- INIT

initSession : Nav.Key -> Session
initSession key =
    { navKey = key
    , translations = I18N.fromTree []
    , language = ""
    , notifications = []
    , nextNotificationId = NotificationId 1
    , settingsVisible = False
    , status = MachineStatus.Shooting
    }

addNotifications : Session -> List Notification -> Session
addNotifications session new =
    let
        newNotifications =
            new
                |> List.indexedMap (createIdentifedNotification session.nextNotificationId)
                |> List.reverse
    in
    { session
        | notifications = newNotifications ++ session.notifications
        , nextNotificationId = addId session.nextNotificationId (List.length newNotifications)
    }


addId : NotificationId -> Int -> NotificationId
addId (NotificationId lhs) rhs =
    NotificationId (lhs + rhs)


createIdentifedNotification : NotificationId -> Int -> Notification -> IdentifiedNotification
createIdentifedNotification (NotificationId base) index { text, nType } =
    let
        id =
            NotificationId (base + index)
    in
    IdentifiedNotification id text nType

toIdString : IdentifiedNotification -> String
toIdString notification =
    case notification.id of
        NotificationId id ->
            String.fromInt id

changeLanguage: Session -> String -> I18N.Translations -> Session
changeLanguage session lang translations =
    { session | language = lang, translations = translations }

navKey: Session -> Nav.Key
navKey session =
    session.navKey

apiErrorToText: Session -> Api.Error.Error -> String
apiErrorToText session error =
    case error of
        Api.Error.Http Http.Timeout ->
            TError.timeout session.translations

        Api.Error.Http (Http.BadStatus status) ->
            TError.badStatus session.translations (String.fromInt status)

        Api.Error.Http (Http.BadBody e) ->
            TError.badBody session.translations e

        Api.Error.Http (Http.BadUrl url) ->
            TError.badUrl session.translations url

        Api.Error.Http Http.NetworkError ->
            TError.networkError session.translations

        Api.Error.Api e ->
            translateError session e

addApiError: Session -> Api.Error.Error -> Session
addApiError session error =
  addNotifications session [ Notification.toNotification { text = apiErrorToText session error, nType = "error" } ]


fromMessage: Session -> Message -> (Session, Message)
fromMessage session message =
  let 
    updated =
      case message of
        Message.MachineStatus status ->
          { session | status = status }
        
        Message.Error err ->
          addNotifications session [ Notification.toNotification { text = translateError session err, nType = "error" } ]

        _ ->
          session
  in
  (updated, message)

translateError: Session -> String -> String
translateError session key =
    I18N.t session.translations key

subscriptions: (Session -> Message -> msg) -> Session -> Sub msg
subscriptions toMsg session =
  Api.message (\msg ->
    let 
      (updated, message) 
        = fromMessage session msg
    in
    toMsg updated message
    )
