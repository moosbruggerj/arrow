module Units.ForceUnit exposing ( ForceUnit(..), toString, fromString, allUnits )

type ForceUnit
    = Newton
    | Pound

toString: ForceUnit -> String
toString unit =
    case unit of
        Newton ->
            "N"

        Pound ->
            "lbs"

fromString: String -> Result String ForceUnit
fromString unit =
    case unit of
        "N" ->
            Ok Newton

        "lbs" ->
            Ok Pound

        _ ->
            Err "unknown unit"

allUnits: List ForceUnit
allUnits =
    [ Newton, Pound ]
