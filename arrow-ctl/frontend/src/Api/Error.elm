module Api.Error exposing (Error(..))

import Http

type Error
    = Http Http.Error
    | Api String
