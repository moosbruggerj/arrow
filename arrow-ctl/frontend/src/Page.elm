module Page exposing ( Msg, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy)
import Translations.Header as THeader
import I18Next as I18N exposing (Translations)
import Notification exposing (Notification)
import Session exposing (Session)
import Route


type Msg
    = DeleteNotification Session.NotificationId
    | ToggleMenu
    | HideMenu



-- INIT


-- VIEW


view : Session -> (Msg -> msg) -> { title : String, content : Html msg, headerElement: Maybe (Html msg) } -> Browser.Document msg
view session toMsg { title, content, headerElement} =
    { title = title ++ " Arro(w)"
    , body = (viewHeader session toMsg headerElement) :: content :: [ viewFooter ]
    }


viewHeader : Session -> (Msg -> msg) -> Maybe (Html msg) -> Html msg
viewHeader session toMsg headerElement =
    div [ class "header", class "is-size-5", style "position" "sticky", style "z-index" "1" ]
        [ viewNotifications session |> Html.map toMsg
        , viewTitleBar session toMsg headerElement
        ]

viewTitleBar: Session -> (Msg -> msg) -> Maybe (Html msg) -> Html msg
viewTitleBar session toMsg insert =
    nav [class "navbar", class "is-transparent", class "is-info" ]
        [ div [ class "navbar-menu", class "is-active" ]
            [ div [ class "navbar-start"]
                [ div ([ class "navbar-item", class "has-dropdown", class "ml-2" ] ++ ( if session.settingsVisible then [ class "is-active" ] else [] ))
                    [ div [ class "navbar-link", class "is-arrowless", onClick ToggleMenu ]
                        [ span [ class "fas", class "fa-cog", class "is-size-2" ] [] ]
                    , div [ class "navbar-dropdown", class "is-boxed" ]
                        [ viewTitleBarIcon "fa-home" (Route.href Route.Home) [ HideMenu ]
                        , viewTitleBarIcon "fa-power-off" (Route.href Route.Home) [ HideMenu ]
                        , viewTitleBarIcon "fa-wrench" (Route.href Route.Settings) [ HideMenu ]
                        ]
                    ]
                ] |> Html.map toMsg
            , div [ class "navbar-end" ]
                (
                    if session.shootingInProgress then
                        [ div [ class "navbar-item" ] 
                            [ a [ class "navbar-link", class "is-arrowless", href "/shooting" ]
                                [ span [ class "fas", class "fa-exclamation-triangle", class "has-text-warning", class "mr-2" ] []
                                , text <| THeader.shooting session.translations
                                ]
                            ]
                        ]
                    else
                        []
                    ++ 
                    [
                        case insert of
                            Nothing -> text ""
                            Just el -> el
                    ]
                )
            ]
        ]

viewTitleBarIcon : String -> Html.Attribute Msg -> List Msg -> Html Msg
viewTitleBarIcon icon link handlers =
    a ([ class "navbar-item", class "p-3", link ] ++
        ( List.map (\h -> onClick h) handlers ))
        [ span [ class "fas", class icon, class "is-size-2" ] [] ]


viewFooter : Html msg
viewFooter =
    div [ id "footer" ] []


viewNotifications : Session -> Html Msg
viewNotifications session =
    Keyed.node "div" 
        [ id "notification-list"
        , class "container"
        , class "is-fluid"
        , style "position" "fixed"
        , style "top" "0px"
        , style "overflow" "auto"
        , style "max-height" "100vh"
        , style "z-index" "9999"
        ]
        (List.map viewKeyedNotification session.notifications)


viewKeyedNotification : Session.IdentifiedNotification -> ( String, Html Msg )
viewKeyedNotification notification =
    ( Session.toIdString notification, lazy viewNotification notification )


viewNotification : Session.IdentifiedNotification -> Html Msg
viewNotification notification =
    let
        cssClass =
            Notification.toCssClass notification.nType

    in
    div [ class "notification", class cssClass, class "mt-4" ]
        [ button [ class "delete", onClick (DeleteNotification notification.id) ] []
        , p [] [ text notification.text ]
        ]



-- UPDATE


update : Msg -> Session -> ( Session, Cmd Msg )
update msg session =
    case msg of
        DeleteNotification id ->
            ( { session | notifications = List.filter (\n -> n.id /= id) session.notifications }, Cmd.none )

        ToggleMenu ->
            ( { session | settingsVisible = not session.settingsVisible }, Cmd.none )

        HideMenu ->
            ( { session | settingsVisible = False }, Cmd.none )
