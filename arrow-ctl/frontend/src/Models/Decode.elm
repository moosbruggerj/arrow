module Models.Decode exposing (maybe)

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline

maybe: String -> Decoder a -> Decoder (Maybe a -> b) -> Decoder b
maybe key decoder =
  Json.Decode.Pipeline.custom (Decode.maybe (Decode.field key decoder))
