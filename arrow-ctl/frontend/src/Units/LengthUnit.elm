module Units.LengthUnit exposing ( LengthUnit(..), toString, fromString, allUnits )

type LengthUnit
    = Inch
    | Millimeter
    | Centimeter
    | Meter

toString: LengthUnit -> String
toString unit =
    case unit of
        Inch ->
            "in"

        Millimeter ->
            "mm"

        Centimeter ->
            "cm"

        Meter ->
            "m"

fromString: String -> Result String LengthUnit
fromString unit =
    case unit of
        "in" ->
            Ok Inch

        "mm" ->
            Ok Millimeter

        "cm" ->
            Ok Centimeter

        "m" ->
            Ok Meter

        _ ->
            Err "unknown unit"

allUnits: List LengthUnit
allUnits =
    [ Inch, Millimeter, Centimeter, Meter ]
