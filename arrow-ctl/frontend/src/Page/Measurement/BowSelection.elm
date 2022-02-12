module Page.Measurement.BowSelection exposing (Msg, Model, init, view, update, toSession, updateSession, subscriptions)

import Browser
import Html exposing (..)
import Html.Attributes as Attr exposing (class, classList, type_, disabled, style)
import Html.Events exposing (onClick, onInput)
import Session exposing (Session)
import Translations.BowSelection as TBowSelection
import Translations.Error as TError
import Translations.Warning as TWarning
import I18Next as I18N
import Translations
import Route exposing (Route)
import Message exposing (Message)
import Message.Request as Request exposing (Request)
import Api
import Api.Error exposing (Error)
import Api.Endpoint
import Models.Bow as Bow exposing (Bow)
import Html.Keyed as Keyed
import Html.Lazy exposing (lazy4)
import Units.LengthUnit as LengthUnit exposing (LengthUnit)
import Units.Length as Length exposing (Length)
import Models exposing (Persisted(..))
import Dict exposing (Dict)
import Http
import Models.Deletion as Deletion
import InputState exposing (InputState)
import InputFields
import Limits exposing (Limits)
import InputParser

type alias Config =
    { maxDrawDistanceUnit: LengthUnit
    , remainderArrowLengthUnit: LengthUnit
    , maxDrawDistanceDisplayUnit: LengthUnit
    , remainderArrowLengthDisplayUnit: LengthUnit
    }

type RemoteData a
    = Loading
    | Data a
    | RemoteError String

type FilterDirection
    = Ascending
    | Descending

type Filter
    = Name FilterDirection
    | Weight FilterDirection
    | Search String

type alias BowList = Dict Int (Bow, Bool)

type alias FormData =
    { name : InputState String
    , maxDrawDistance : InputState Length
    , remainderArrowLength : InputState Length
    }

emptyFormData: FormData
emptyFormData =
    { name = InputState.Empty
    , maxDrawDistance = InputState.Empty
    , remainderArrowLength = InputState.Empty
    }

type EditState
    = None
    | New FormData Bool
    | Edit Bow.Id FormData Bool
    | Delete Bow Bool

type alias Model =
    { session: Session
    , bows: RemoteData BowList
    , filter: List Filter
    , edit: EditState
    , config: Config
    }

type Msg
    = BowSelected Bow
    | SetMaxDrawDistanceUnit String
    | SetRemainderArrowLengthUnit String
    | SetName String
    | SetMaxDrawDistance String
    | SetRemainderArrowLength String
    | SubmitNew
    | SubmitEdit Bow.Id
    | SubmitDelete Bow.Id
    | NewBow
    | EditBow Bow
    | DeleteBow Bow
    | Cancel
    | GotMessage Session Message
    | GotBows (Result Error (List Bow))
    | GotBow (Result Error (Bow))
    | GotBowDeletion (Result Error Bow.Id)

-- INIT

remainderArrowLengthLimits: Limits Length
remainderArrowLengthLimits =
    { min = Just (Length.Millimeter 0)
    , max = Nothing
    , warningMin = Just (Length.Millimeter 5)
    , warningMax = Just (Length.Millimeter 300)
    }

maxDrawDistanceLimits: Limits Length
maxDrawDistanceLimits =
    { min = Just (Length.Millimeter 0)
    , max = Just (Length.Millimeter 2000) -- TODO: use maximum from machine config
    , warningMin = Just (Length.Millimeter 300)
    , warningMax = Just (Length.Millimeter 1900) -- TODO: proportional to max
    }

init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
    , bows = Loading
    , filter = []
    , edit = None
    , config = configfromSession session
    }
    , fetchBows
    )

configfromSession: Session -> Config
configfromSession _ =
    { maxDrawDistanceUnit = LengthUnit.Millimeter
    , remainderArrowLengthUnit = LengthUnit.Millimeter
    , maxDrawDistanceDisplayUnit = LengthUnit.Millimeter
    , remainderArrowLengthDisplayUnit = LengthUnit.Millimeter
    }

-- VIEW
view : Model -> { title: String, content: Html Msg, headerElement: Maybe (Html Msg) }
view model =
    { title = "Select Bow"
    , content = viewBody model
    , headerElement = Just (viewFilter model)
    }

viewFilter : Model -> Html Msg
viewFilter model =
    div [] []

viewBody: Model -> Html Msg
viewBody model =
    let
        translations = 
            model.session.translations
    in
    case model.bows of
        Loading ->
            div [ class "has-text-centered", class "is-size-1" ]
            [ span [ class "fas", class "fa-sync-alt", class "mr-2" ] []
            , text (Translations.loading translations)
            ]

        Data bows ->
            div []
            [ viewBows model bows
            , viewEdit model
            , viewFooter model
            ]

        RemoteError e ->
            div [ class "has-text-centered", class "is-size-1" ]
            [ span [ class "fas", class "fa-sync-alt", class "mr-2" ] []
            , text e
            ]

viewBows: Model -> BowList -> Html Msg
viewBows model bows =
    let
        bowList = Dict.values bows
    in
    case bowList of
        [] ->
           div [ class "has-text-centered", class "is-size-3" ] ( viewEmptyText model )

        _ -> 
            Keyed.node "div" 
            []
            (("header", viewListHeader model) :: (List.map (viewKeyedBow model) bowList)) -- TODO: Filter/sort

viewListHeader: Model -> Html msg
viewListHeader model =
    let
        translations = model.session.translations
    in
    div 
        [ class "is-fluid"
        , class "columns"
        , class "mt-0"
        , class "box"
        , class "sticky-header"
        , class "has-text-weight-bold"
        , class "py-0"
        ]
        [ div [ class "column", class "is-two-fifths" ] [ span [] [ text (TBowSelection.name translations) ] ]
        , div [ class "column" ] [ span [] [ text (TBowSelection.maxDrawDistance translations) ] ]
        , div [ class "column" ] [ span [] [ text (TBowSelection.remainderArrowLength translations) ] ]
        , div [ class "column", class "has-text-right" ] []
        , div [ class "column", class "is-1" ] []
        ]

viewEmptyText : Model -> List (Html msg)
viewEmptyText model =
    let
        translated = TBowSelection.emptyList model.session.translations
    in
    String.split "\n" translated
        |> List.map (\t -> p [] [ text t ])

viewKeyedBow: Model -> (Bow, Bool) -> (String, Html Msg)
viewKeyedBow model (bow, isSelected) =
    let
        id = Models.toId bow
        config = model.config
        translations = model.session.translations
    in
    (Bow.idToString id, lazy4 viewBow translations config bow isSelected)

viewBow: I18N.Translations -> Config -> Bow -> Bool -> Html Msg
viewBow translations config bow isSelected =
    let
        bowData = Models.toData bow
    in
    div 
        [ class "is-fluid"
        , class "columns"
        , class "mt-3"
        , class "box"
        , classList 
            [ ("has-background-primary-dark", isSelected)
            , ("has-text-white", isSelected) ]
        , onClick (BowSelected bow)
        ]
        [ div [ class "column", class "is-two-fifths" ] [ text bowData.name ]
        , div [ class "column" ] [ text (toDisplayString config.maxDrawDistanceDisplayUnit bowData.maxDrawDistance) ]
        , div [ class "column" ] [ text (toDisplayString config.remainderArrowLengthDisplayUnit bowData.remainderArrowLength) ]
        , div [ class "column", class "has-text-right" ] 
            [ button 
                [ class "button"
                , class "is-round"
                , onClick (EditBow bow)
                ]
                [ span 
                    [ class "icon", class "is-medium" ]
                    [ span [ class "fas", class "fa-pencil-alt" ] [] ]
                ]
            , button 
                [ class "button"
                , class "is-round"
                , class "ml-2"
                , onClick (DeleteBow bow)
                ]
                [ span 
                    [ class "icon", class "is-medium" ]
                    [ span [ class "far", class "fa-trash-alt" ] [] ]
                ]
            ]
        , div [ class "column", class "is-1" ] []
        ]

toDisplayString: LengthUnit -> Length -> String
toDisplayString unit length =
    let
        rounded =
            Length.to unit length
                |> Length.toRounded
    in
    String.join " " [rounded, LengthUnit.toString unit]

viewEdit: Model -> Html Msg
viewEdit model =
    case model.edit of
        None ->
            div [] []

        New data submitting->
            viewFormModal model data submitting SubmitNew

        Edit id data submitting ->
            viewFormModal model data submitting (SubmitEdit id)

        Delete bow submitting ->
            viewDeleteModal model bow submitting (SubmitDelete (Models.toId bow))

viewDeleteModal: Model -> Bow -> Bool -> Msg -> Html Msg
viewDeleteModal model (Persisted id data) submitting submitMsg =
    let
        translations = model.session.translations
    in
    div [ class "modal", class "is-active" ]
        [ div [ class "modal-background", onClick Cancel ] []
        , div [ class "modal-card" ] 
            [ header [ class "modal-card-head" ]
                [ p [ class "modal-card-title" ]
                    [ text (TBowSelection.deleteConfirmHeader translations) ]
                , button [ class "delete", onClick Cancel ] []
                ]
            , section [ class "modal-card-body" ]
                [ text (TBowSelection.deleteConfirm translations data.name) ]
            , footer [ class "modal-card-foot" ]
                [ button [ class "button", class "is-danger", class "is-medium", classList [ ("is-loading", submitting ) ], disabled submitting, onClick submitMsg ] [ text (Translations.delete translations) ]
                , button [ class "button", class "is-medium", disabled submitting, onClick Cancel ] [ text (Translations.cancel translations) ]
                ]
            ]
        ]

viewFormModal: Model -> FormData -> Bool -> Msg -> Html Msg
viewFormModal model data submitting submitMsg =
    div [ class "modal", class "is-active" ]
        [ div [ class "modal-background", onClick Cancel ] []
        , div [ class "modal-card" ] ( viewForm model.session.translations submitMsg model.config data submitting )
        ]

viewForm: I18N.Translations -> Msg -> Config -> FormData -> Bool -> List (Html Msg)
viewForm translations submitMsg config bowData submitting =
    [ header [ class "modal-card-head" ]
        [ p [ class "modal-card-title" ] 
            [ text ( formTitle translations bowData ) ]
        , button [ class "delete", onClick Cancel ] []
        ]
    , section [ class "modal-card-body" ]
        [ InputFields.textField
            (TBowSelection.name translations)
            bowData.name
            SetName
        , InputFields.lengthField
            (TBowSelection.maxDrawDistance translations)
            bowData.maxDrawDistance
            config.maxDrawDistanceUnit
            { toValueMsg = SetMaxDrawDistance
            , toUnitMsg = SetMaxDrawDistanceUnit
            }
        , InputFields.lengthField
            (TBowSelection.remainderArrowLength translations)
            bowData.remainderArrowLength
            config.remainderArrowLengthUnit
            { toValueMsg = SetRemainderArrowLength
            , toUnitMsg = SetRemainderArrowLengthUnit
            }
        ]
    , footer [ class "modal-card-foot" ]
        [ button [ class "button", class "is-success", class "is-medium", classList [ ("is-loading", submitting ) ], disabled submitting, onClick submitMsg ] [ text (TBowSelection.saveBow translations) ]
        , button [ class "button", class "is-medium", disabled submitting, onClick Cancel ] [ text (Translations.cancel translations) ]
        ]
    ]

formTitle: I18N.Translations -> FormData -> String
formTitle translations bowData =
    let
        name = InputState.stringValue bowData.name identity
    in
    (TBowSelection.newBow translations) ++ 
    (if String.length name /= 0
     then 
         ": " ++ name 
     else
         ""
    ) 

viewFooter: Model -> Html Msg
viewFooter model =
    let
        activeBows =
            case model.bows of
                Loading ->
                    []

                Data bows ->
                    List.filter (\(_, a) -> a) (Dict.values bows)

                RemoteError _ ->
                    []

        href = 
            case activeBows of
                [ bow ] ->
                    [ Route.href Route.Home ]

                _ ->
                    []

    in
    div
        [ class "fixed-bottom-right" ]
        [ div [] 
            [ a 
                ([ class "button"
                , class "mb-3"
                , class "mr-5"
                , class "is-round"
                , class "is-primary"
                , class "is-large"
                , class "is-size-3"
                , onClick NewBow -- TODO: fix Msg
                , classList [ ("is-hidden", List.length href /= 1) ]
                ] ++ href)
                [ span 
                    [ class "icon", class "is-large" ]
                    [ span [ class "fas", class "fa-arrow-right" ] [] ]
                ]
            ]
        , div [] 
            [ button 
                [ class "button"
                , class "mb-5"
                , class "mr-5"
                , class "is-round"
                , class "is-primary"
                , class "is-large"
                , class "is-size-3"
                , onClick NewBow
                ]
                [ span 
                    [ class "icon", class "is-large" ]
                    [ span [ class "fas", class "fa-plus" ] [] ]
                ]
            ]
        ]

fetchBows: Cmd Msg
fetchBows =
    Api.get (\res ->
        case res of
            Err a ->
                GotBows (Err a)

            Ok (Message.BowList bows) ->
                GotBows (Ok bows)

            Ok msg ->
                GotBows (Err (Api.Error.Api "TODO")) -- TODO
        )
        Api.Endpoint.listBows

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    let
        translations = model.session.translations
    in
    case message of
        BowSelected bow ->
            case model.bows of
                Data bows ->
                    ( { model | bows = Data (Dict.map (\_ (b, _) -> (b, Models.equals b bow)) bows ) }, Cmd.none)
                _ ->
                    ( model, Cmd.none )

        NewBow ->
            ( { model | edit = New emptyFormData False } , Cmd.none )

        SetMaxDrawDistanceUnit unitStr ->
            let
                parsedUnit = LengthUnit.fromString unitStr
            in
            case parsedUnit of
                Err _ ->
                    ( model, Cmd.none )

                Ok unit ->
                    let
                        editState =
                            updateEditState model.edit
                            (\data ->
                                { data | maxDrawDistance = updateLength data.maxDrawDistance unit }
                            )

                        oldConfig = model.config
                    in
                    ( { model | config = { oldConfig | maxDrawDistanceUnit = unit }
                        , edit = editState }, Cmd.none )

        SetRemainderArrowLengthUnit unitStr ->
            let
                parsedUnit = LengthUnit.fromString unitStr
            in
            case parsedUnit of
                Err _ ->
                    ( model, Cmd.none )
                Ok unit ->
                    let
                        editState =
                            updateEditState model.edit
                            (\data ->
                                { data | remainderArrowLength = updateLength data.remainderArrowLength unit }
                            )

                        oldConfig = model.config
                    in
                    ( { model | config = { oldConfig | remainderArrowLengthUnit = unit }
                        , edit = editState }, Cmd.none )

        SetName name ->
            let
                editState =
                    updateEditState model.edit
                    (\data ->
                        { data | name = InputParser.required name translations}
                    )
            in
            ( { model | edit = editState }, Cmd.none )

        SetMaxDrawDistance distance ->
            let
                editState =
                    updateEditState model.edit
                    (\data ->
                        { data | maxDrawDistance = InputParser.length distance model.config.maxDrawDistanceUnit maxDrawDistanceLimits translations }
                    )
            in
            ( { model | edit = editState }, Cmd.none )

        SetRemainderArrowLength remainder ->
            let
                editState =
                    updateEditState model.edit
                    (\data ->
                        { data | remainderArrowLength = InputParser.length remainder model.config.remainderArrowLengthUnit remainderArrowLengthLimits translations }
                    )
            in
            ( { model | edit = editState }, Cmd.none )

        SubmitNew ->
            let
                (state, _, data) = submittingEditState model.edit True
                cmd = case data of
                    Just d ->
                        Api.request (expectBow translations) Api.Endpoint.modifyBow (Http.jsonBody (Bow.encodeData d))

                    Nothing ->
                        Cmd.none

            in
            ( { model | edit = state }, cmd )

        SubmitEdit id ->
            let
                (state, i, data) = submittingEditState model.edit True
                cmd = case data of
                    Just d ->
                        Api.request (expectBow translations) Api.Endpoint.modifyBow (Http.jsonBody (Bow.encode (Persisted id d)))

                    Nothing ->
                        Cmd.none

            in
            ( { model | edit = state }, cmd )

        SubmitDelete _ ->
            let
                (state, id, _) = submittingEditState model.edit True
                cmd = case id of
                    Just i ->
                        Api.request (expectBowDelete translations) (Api.Endpoint.deleteBow i) Http.emptyBody

                    Nothing ->
                        Cmd.none

            in
            ( { model | edit = state }, cmd )

        DeleteBow bow ->
            ( { model | edit = Delete bow False }, Cmd.none )

        EditBow bow ->
            ( { model | edit = editFromBow bow }, Cmd.none )

        Cancel ->
            ( { model | edit = None }, Cmd.none )

        GotBows (Err err) ->
            ( updateSession (Session.addApiError model.session err) model , Cmd.none )

        GotBows (Ok bows) ->
            ( { model | bows = Data ( (List.map (\b -> (Bow.idToInt (Models.toId b), (b, False))) bows) |> Dict.fromList) }, Cmd.none)

        GotBow (Err err) ->
            ( updateSession (Session.addApiError model.session err) { model | edit = None }, Cmd.none )

        GotBow (Ok bow) ->
            ( { model | bows = Data (updateBowList model [ bow ] True )
                , edit = None }, Cmd.none )

        GotBowDeletion (Err err) ->
            ( updateSession (Session.addApiError model.session err) { model | edit = None }, Cmd.none )

        GotBowDeletion (Ok id) ->
            ( { model | bows = deleteFromBowList model id
                , edit = None }, Cmd.none )

        GotMessage session msg ->
            updateOnMessage { model | session = session } msg

expectBowDelete: I18N.Translations -> Result Error Message -> Msg
expectBowDelete translations msg =
    GotBowDeletion <|
    case msg of
        Err e ->
            Err e

        Ok (Message.Error e) ->
            Err (Api.Error.Api e)

        Ok (Message.Deletion (Deletion.BowDeletion id )) ->
            Ok (id)

        Ok (Message.Deletion del ) ->
            Err (Api.Error.Api (TError.unexpectedDeletion translations (Deletion.typeToString del)))

        Ok ( m ) ->
            Err (Api.Error.Api (TError.unexpectedMessageType translations "Deletion" (Message.typeToString m)))

expectBow: I18N.Translations -> Result Error Message -> Msg
expectBow translations msg =
    GotBow <|
    case msg of
        Err e ->
            Err e

        Ok (Message.Error e) ->
            Err (Api.Error.Api e)

        Ok (Message.BowList [ bow ] ) ->
            Ok (bow)

        Ok (Message.BowList bows ) ->
            Err (Api.Error.Api (TError.unexpectedArgNum translations "1" (String.fromInt (List.length bows))))

        Ok ( m ) ->
            Err (Api.Error.Api (TError.unexpectedMessageType translations "BowList" (Message.typeToString m)))

editFromBow: Bow -> EditState
editFromBow (Persisted id data) =
    Edit id
        { name = InputState.Validated data.name
        , maxDrawDistance = InputState.Validated data.maxDrawDistance
        , remainderArrowLength = InputState.Validated data.remainderArrowLength
        }
        False


parseBowForm: FormData -> Maybe Bow.Data
parseBowForm data =
    let
        name = InputState.toMaybe data.name
        maxDrawDistance = InputState.toMaybe data.maxDrawDistance
        remainderArrowLength = InputState.toMaybe data.remainderArrowLength
    in
    case (name, maxDrawDistance, remainderArrowLength) of
        (Just n, Just dd, Just rem) ->
            Just (Bow.Data n dd rem)

        _ ->
            Nothing

submittingEditState: EditState -> Bool -> (EditState, Maybe Bow.Id, Maybe Bow.Data)
submittingEditState state submitting =
    let
        valid parsed old =
            case parsed of
                Nothing ->
                    old

                Just _ ->
                    submitting
    in
    case state of
        None ->
            (None, Nothing, Nothing)

        New data oldSub ->
            let
                parsed = parseBowForm data
                sub = valid parsed oldSub
            in
            (New data sub, Nothing, parsed)

        Edit id data oldSub ->
            let
                parsed = parseBowForm data
                sub = valid parsed oldSub
            in
            (Edit id data sub, Just id, parsed)

        Delete bow _ ->
            (Delete bow submitting, Just (Models.toId bow), Just (Models.toData bow))

updateEditState: EditState -> (FormData -> FormData) -> EditState
updateEditState state updater =
    case state of
        None ->
            None

        New data False ->
            New (updater data) False

        New data True ->
            state

        Edit id data False ->
            Edit id (updater data) False

        Edit id data True ->
            state

        Delete _ _ ->
            state

updateLength: InputState Length -> LengthUnit -> InputState Length
updateLength state unit =
    InputState.update state (Length.to unit)

updateOnMessage : Model -> Message -> ( Model, Cmd Msg )
updateOnMessage model msg =
    case msg of
        Message.BowList bows ->
            let
                setSelected = False
            in
            ( { model | bows = Data (updateBowList model bows setSelected) }, Cmd.none)

        _ ->
            (model, Cmd.none)

deleteFromBowList: Model -> Bow.Id -> RemoteData BowList
deleteFromBowList model id =
    case model.bows of
        Data list ->
            Data (Dict.remove (Bow.idToInt id) list)

        a ->
            a

mergeBowList: BowList -> List (Bow, Bool) -> BowList
mergeBowList list new =
    List.foldl (\(bow, a) l -> Dict.insert (Bow.idToInt (Models.toId bow)) (bow, a) l) list new

updateBowList: Model -> List Bow -> Bool -> BowList
updateBowList model bows setSelected =
    case model.bows of
        Data list ->
            if setSelected then
                mergeBowList 
                    (Dict.map (\_ (b, _) -> (b, False)) list)
                    (List.indexedMap (\i b -> (b, i == 0)) bows)
            else
                mergeBowList list (List.map (\b -> (b, False)) bows)

        _ ->
            List.indexedMap (\i b -> (Bow.idToInt (Models.toId b), (b, i == 0 && setSelected))) bows
                |> Dict.fromList


toSession: Model -> Session
toSession model =
    model.session

updateSession: Session -> Model -> Model
updateSession session model =
    { model | session = session }

subscriptions: Model -> Sub Msg
subscriptions model =
    let
        session = toSession model
    in
    Session.subscriptions GotMessage session
