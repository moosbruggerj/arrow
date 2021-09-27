module Notification exposing (NotificationType, Notification, toCssClass, toNotification)

type NotificationType
    = Error
    | Warning
    | Info

type alias Notification =
    { text : String
    , nType : NotificationType
    }

toCssClass : NotificationType -> String
toCssClass nType =
    case nType of
        Error ->
            "is-danger"

        Warning ->
            "is-warning"

        Info ->
            "is-info"


toNotification : { text : String, nType : String } -> Notification
toNotification { text, nType } =
    let
        notificationType =
            case nType of
                "error" ->
                    Error

                "warning" ->
                    Warning

                _ ->
                    Info
    in
    Notification text notificationType
