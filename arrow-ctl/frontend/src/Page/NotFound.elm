module Page.NotFound exposing (view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Session exposing (Session)

-- VIEW
view : { title: String, content: Html msg, headerElement: Maybe (Html msg) }
view =
    { title = "Not Found"
    , content = viewNotFound
    , headerElement = Nothing
    }

viewNotFound: Html msg
viewNotFound =
    div [ class "has-text-centered", class "is-size-1", class "mt-5" ]
    [ text "Page not Found" ]
