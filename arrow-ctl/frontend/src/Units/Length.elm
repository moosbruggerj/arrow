module Units.Length exposing (Length(..), to, toString, toUnit, toNumber, fromParts, less, encode, decoder, toRounded)

import Units.LengthUnit as LengthUnit exposing (LengthUnit)
import Json.Encode as Encode
import Json.Decode as Decode exposing (Decoder)
import Round

type Length
    = Inch Float
    | Millimeter Float
    | Centimeter Float
    | Meter Float

to: LengthUnit -> Length -> Length
to unit from =
    case unit of
        LengthUnit.Inch ->
            toInch from

        LengthUnit.Millimeter ->
            toMm from

        LengthUnit.Centimeter ->
            toCm from

        LengthUnit.Meter ->
            toM from

mmConstant: Float
mmConstant = 25.4

mToMm: Float -> Float
mToMm m =
    m * 1000.0

cmToMm: Float -> Float
cmToMm cm =
    cm * 10.0

mmToCm: Float -> Float
mmToCm mm =
    mm / 10.0

mmToM: Float -> Float
mmToM mm =
    mm / 1000.0

toInch: Length -> Length
toInch from =
    case from of
        Inch l ->
            Inch l

        Millimeter l ->
            Inch (l / mmConstant)

        Centimeter l ->
            Inch ((cmToMm l) / mmConstant)

        Meter l ->
            Inch ((mToMm l) / mmConstant)

toMm: Length -> Length
toMm from =
    case from of
        Inch l ->
            Millimeter (l * mmConstant)

        Millimeter l ->
            Millimeter l

        Centimeter l ->
            Millimeter (cmToMm l)

        Meter l ->
            Millimeter (mToMm l)


toCm: Length -> Length
toCm from =
    case from of
        Inch l ->
            Centimeter (mmToCm (l * mmConstant))

        Millimeter l ->
            Centimeter (mmToCm l)

        Centimeter l ->
            Centimeter l

        Meter l ->
            Centimeter (mmToCm (mToMm l))

toM: Length -> Length
toM from =
    case from of
        Inch l ->
            Meter (mmToM (l * mmConstant))

        Millimeter l ->
            Meter (mmToM l)

        Centimeter l ->
            Meter (mmToM (cmToMm l))

        Meter l ->
            Meter l

toUnit: Length -> LengthUnit
toUnit length =
    case length of
        Inch _ ->
            LengthUnit.Inch

        Millimeter _ ->
            LengthUnit.Millimeter

        Centimeter _ ->
            LengthUnit.Centimeter

        Meter _ ->
            LengthUnit.Meter

toNumber: Length -> Float
toNumber length =
    case length of
        Inch l ->
            l

        Millimeter l ->
            l

        Centimeter l ->
            l

        Meter l ->
            l

toString: Length -> String
toString length =
    length 
        |> toNumber
        |> String.fromFloat

toRounded: Length -> String
toRounded length =
    let
        digits =
            significantDigits length
    in
    Round.round digits (toNumber length)

significantDigits: Length -> Int
significantDigits length =
    case toUnit length of
        LengthUnit.Inch ->
            2

        LengthUnit.Millimeter ->
            1

        LengthUnit.Centimeter ->
            2

        LengthUnit.Meter ->
            4

fromParts: Float -> LengthUnit -> Length
fromParts length unit =
    case unit of
        LengthUnit.Inch ->
            Inch length

        LengthUnit.Millimeter ->
            Millimeter length

        LengthUnit.Centimeter ->
            Centimeter length

        LengthUnit.Meter ->
            Meter length

less: Length -> Length -> Bool
less lhs rhs =
    let
        unit = toUnit lhs
        lhsNum = lhs |> toNumber
        rhsNum = rhs |> to unit |> toNumber
    in
    lhsNum < rhsNum

encode: Length -> Encode.Value
encode =
    to LengthUnit.Meter
        >> toNumber
        >> Encode.float

decoder: Decoder Length
decoder =
    Decode.map (\f -> fromParts f LengthUnit.Meter) Decode.float
