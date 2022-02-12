module Units.Force exposing (Force(..), to, toString, toUnit, toNumber, fromParts, less, encode, decoder, toRounded)

import Units.ForceUnit as ForceUnit exposing (ForceUnit)
import Json.Encode as Encode
import Json.Decode as Decode exposing (Decoder)
import Round

type Force
    = Newton Float
    | Pound Float

to: ForceUnit -> Force -> Force
to unit from =
    case unit of
        ForceUnit.Newton ->
            toNewton from

        ForceUnit.Pound ->
            toPound from


poundConstant = 4.448222

toNewton: Force -> Force
toNewton from =
    case from of
        Newton f ->
            Newton f

        Pound f ->
            Newton (f * poundConstant)

toPound: Force -> Force
toPound from =
    case from of
        Newton f ->
            Pound (f / poundConstant)

        Pound f ->
            Pound f

toUnit: Force -> ForceUnit
toUnit length =
    case length of
        Newton _ ->
            ForceUnit.Newton

        Pound _ ->
            ForceUnit.Pound

toNumber: Force -> Float
toNumber force =
    case force of
        Newton f ->
            f

        Pound f ->
            f

toString: Force -> String
toString force =
    force 
        |> toNumber
        |> String.fromFloat

toRounded: Force -> String
toRounded force =
    let
        digits =
            significantDigits force
    in
    Round.round digits (toNumber force)

significantDigits: Force -> Int
significantDigits _ =
    2

fromParts: Float -> ForceUnit -> Force
fromParts force unit =
    case unit of
        ForceUnit.Newton ->
            Newton force

        ForceUnit.Pound ->
            Pound force

less: Force -> Force -> Bool
less lhs rhs =
    let
        unit = toUnit lhs
        lhsNum = lhs |> toNumber
        rhsNum = rhs |> to unit |> toNumber
    in
    lhsNum < rhsNum

encode: Force -> Encode.Value
encode =
    to ForceUnit.Newton
        >> toNumber
        >> Encode.float

decoder: Decoder Force
decoder =
    Decode.map (\f -> fromParts f ForceUnit.Newton) Decode.float
