module Models.Encode exposing (required, maybe, object)

import Json.Encode as Encode

maybe: String -> (a -> Encode.Value) -> Maybe a -> Maybe ( String, Encode.Value)
maybe key encoder data =
  case data of
    Just value ->
      Just (key, encoder value)

    Nothing ->
      Nothing

required: String -> (a -> Encode.Value) -> a -> Maybe ( String, Encode.Value)
required key encoder data =
  Just (key, encoder data)

object: List (Maybe ( String, Encode.Value)) -> Encode.Value
object data =
  List.filterMap identity data
    |> Encode.object
