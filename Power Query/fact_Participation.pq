let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the Participation workbooks (both names contain "participation")
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "participation")),

    // 3. Cohort and Track from the folder path
    AddCohort = Table.AddColumn(Files, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddTrack = Table.AddColumn(AddCohort, "Track", each fn_GetTrack([Folder Path]), type text),

    // 4. Open each workbook's first sheet (sheet names differ: "Sheet1" vs "Participation")
    AddData = Table.AddColumn(AddTrack, "Data", each
        let
            Sheets = Excel.Workbook([Content], true),
            FirstSheet = Table.SelectRows(Sheets, each [Kind] = "Sheet"){0}[Data]
        in
            FirstSheet),
    KeepCols = Table.SelectColumns(AddData, {"Cohort", "Track", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data", {"Date", "Participants"}),

    // 5. Date is stored as text like "05-Aug-2024" (also copes with real dates)
    FixDate = Table.TransformColumns(Expanded, {{"Date", each
        if Value.Is(_, type date) then _
        else if Value.Is(_, type datetime) then Date.From(_)
        else Date.FromText(Text.Trim(Text.From(_)), [Format = "dd-MMM-yyyy", Culture = "en-US"]),
        type date}}),

    // 6. Turn "Harper Adams, Aria Turner, ..." into a list of trimmed names
    AddNames = Table.AddColumn(FixDate, "Name", each
        List.Select(
            List.Transform(Text.Split(Text.From([Participants]), ","), Text.Trim),
            each _ <> "")),

    // 7. SPLIT INTO ROWS: one row per name
    KeepCols2 = Table.SelectColumns(AddNames, {"Cohort", "Track", "Date", "Name"}),
    OneRowPerName = Table.ExpandListColumn(KeepCols2, "Name"),
    Typed = Table.TransformColumnTypes(OneRowPerName, {{"Name", type text}}),

    // 8. Safety: if a name appears twice on the same day, count it once
    NoDupes = Table.Distinct(Typed, {"Cohort", "Track", "Date", "Name"}),

    // 9. MERGE on Cohort + Track + Name to find the learner in dim_Learner
    Merged = Table.NestedJoin(NoDupes, {"Cohort", "Track", "Name"},
        dim_Learner, {"Cohort", "Track", "Learner Name"}, "Lookup", JoinKind.LeftOuter),
    AddKeys = Table.ExpandTableColumn(Merged, "Lookup", {"Learner Key", "Email"}),

    // 10. Week number counted from THIS cohort's start date
    MergedCohort = Table.NestedJoin(AddKeys, {"Cohort"}, stg_Cohorts, {"Cohort"}, "CohortInfo", JoinKind.LeftOuter),
    AddCohortStart = Table.ExpandTableColumn(MergedCohort, "CohortInfo", {"Cohort Start Date"}),
    AddWeek = Table.AddColumn(AddCohortStart, "Week", each
        Number.RoundDown(Duration.Days([Date] - [Cohort Start Date]) / 7) + 1, Int64.Type),

    // 11. Tidy up
    RemoveStart = Table.RemoveColumns(AddWeek, {"Cohort Start Date"}),
    TypedKeys = Table.TransformColumnTypes(RemoveStart, {{"Learner Key", type text}, {"Email", type text}}),
    Reordered = Table.ReorderColumns(TypedKeys,
        {"Learner Key", "Cohort", "Track", "Week", "Date", "Email", "Name"})
in
    Reordered
