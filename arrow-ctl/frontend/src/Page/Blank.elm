module Page.Blank exposing (view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Session exposing (Session)

-- VIEW
view : { title: String, content: Html msg, headerElement: Maybe (Html msg) }
view =
    { title = ""
    , content = div [] []
    , headerElement = Nothing
    }
