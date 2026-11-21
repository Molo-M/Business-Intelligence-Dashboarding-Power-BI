let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the Labs & Quizzes workbooks (both file names contain "quiz").
    //    "~$" files are temporary lock files Excel creates while a workbook is open.
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "quiz")),

    // 3. Cohort and Track from the folder path
    AddCohort = Table.AddColumn(Files, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddTrack = Table.AddColumn(AddCohort, "Track", each fn_GetTrack([Folder Path]), type text),

    // 4. Open each workbook. "true" = use the first row of each sheet as headers
    AddSheets = Table.AddColumn(AddTrack, "Sheets", each Excel.Workbook([Content], true)),
    KeepCols = Table.SelectColumns(AddSheets, {"Cohort", "Track", "Sheets"}),
    ExpandSheets = Table.ExpandTableColumn(KeepCols, "Sheets",
        {"Name", "Kind", "Data"}, {"Sheet", "Kind", "Data"}),

    // 5. Keep real worksheets only (workbooks can also contain named ranges/tables)
    OnlySheets = Table.SelectRows(ExpandSheets, each [Kind] = "Sheet"),

    // 6. Type comes from the sheet name
    AddType = Table.AddColumn(OnlySheets, "Type", each
        if Text.StartsWith([Sheet], "Lab") then "Lab"
        else if Text.StartsWith([Sheet], "Quiz") then "Quiz"
        else null, type text),

    // 7. UNPIVOT each sheet: Week 1 ... Week 10 columns become rows
    AddLong = Table.AddColumn(AddType, "Long", each
        Table.UnpivotOtherColumns([Data], {"email"}, "Week Label", "Score")),

    // 8. Stack all unpivoted sheets into one table
    KeepCols2 = Table.SelectColumns(AddLong, {"Cohort", "Track", "Type", "Long"}),
    Expanded = Table.ExpandTableColumn(KeepCols2, "Long",
        {"email", "Week Label", "Score"}, {"Email", "Week Label", "Score"}),

    // 9. Tidy email to match the other tables
    Cleaned = Table.TransformColumns(Expanded, {{"Email", each Text.Lower(Text.Trim(_)), type text}}),

    // 10. "Week 3" -> 3
    AddWeek = Table.AddColumn(Cleaned, "Week", each
        Number.From(Text.AfterDelimiter([Week Label], "Week ")), Int64.Type),

    // 11. Monday of that week, counted from THIS cohort's start date
    MergedCohort = Table.NestedJoin(AddWeek, {"Cohort"}, stg_Cohorts, {"Cohort"}, "CohortInfo", JoinKind.LeftOuter),
    AddCohortStart = Table.ExpandTableColumn(MergedCohort, "CohortInfo", {"Cohort Start Date"}),
    AddWeekStart = Table.AddColumn(AddCohortStart, "Week Start Date", each
        Date.AddDays([Cohort Start Date], ([Week] - 1) * 7), type date),

    // 12. Learner Key (same format as fact_Attendance)
    AddKey = Table.AddColumn(AddWeekStart, "Learner Key", each
        [Cohort] & "|" & [Track] & "|" & [Email], type text),

    // 13. Final tidy-up: drop helper columns, set types, order columns
    RemoveCols = Table.RemoveColumns(AddKey, {"Week Label", "Cohort Start Date"}),
    Typed = Table.TransformColumnTypes(RemoveCols, {{"Score", type number}}),
    Reordered = Table.ReorderColumns(Typed,
        {"Learner Key", "Cohort", "Track", "Type", "Week", "Week Start Date", "Email", "Score"})
in
    Reordered
