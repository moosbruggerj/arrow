module Models exposing ( Persisted(..), encode, toId, toData, equals )

import Json.Encode as Encode
import Models.Encode as E

type Persisted id data
  = Persisted id data

encode: Persisted a b -> (a -> Encode.Value) -> (b -> List (Maybe (String, Encode.Value))) -> Encode.Value
encode (Persisted id data ) encodeId encodeData =
  let
      encodedId = E.required "id" encodeId id
  in
  E.object
    (encodedId ::
      (encodeData <| data)
    )

toId: Persisted id data -> id
toId (Persisted id _) =
  id

toData: Persisted id data -> data
toData (Persisted _ data) =
  data

equals: Persisted id data -> Persisted id data -> Bool
equals (Persisted lhs _) (Persisted rhs _) =
  lhs == rhs
