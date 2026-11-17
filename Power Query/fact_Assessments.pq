let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the two Labs & Quizzes workbooks.
    //    The file names differ between tracks, but both contain "quiz".
    //    "~$" files are temporary lock files Excel creates while a workbook is open.
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "quiz")),

    // 3. Track comes from the folder path (same logic as fact_Attendance)
    AddTrack = Table.AddColumn(Files, "Track", each
        if Text.Contains([Folder Path], "Cloud Training") then "AWS Cloud"
        else if Text.Contains([Folder Path], "PowerBI Training") then "Power BI"
        else null, type text),

    // 4. Open each workbook. "true" = use the first row of each sheet as headers
    AddSheets = Table.AddColumn(AddTrack, "Sheets", each Excel.Workbook([Content], true)),
    KeepCols = Table.SelectColumns(AddSheets, {"Track", "Sheets"}),
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

    // 8. Stack all 4 unpivoted sheets (2 tracks x Labs/Quizzes) into one table
    KeepCols2 = Table.SelectColumns(AddLong, {"Track", "Type", "Long"}),
    Expanded = Table.ExpandTableColumn(KeepCols2, "Long",
        {"email", "Week Label", "Score"}, {"Email", "Week Label", "Score"}),

    // 9. Tidy email to match the other tables
    Cleaned = Table.TransformColumns(Expanded, {{"Email", each Text.Lower(Text.Trim(_)), type text}}),

    // 10. "Week 3" -> 3
    AddWeek = Table.AddColumn(Cleaned, "Week", each
        Number.From(Text.AfterDelimiter([Week Label], "Week ")), Int64.Type),

    // 11. Monday of that week, so assessments can join the shared calendar later
    AddWeekStart = Table.AddColumn(AddWeek, "Week Start Date", each
        Date.AddDays(ProgramStartDate, ([Week] - 1) * 7), type date),

    // 12. Final tidy-up: drop helper column, set types, order columns
    RemoveLabel = Table.RemoveColumns(AddWeekStart, {"Week Label"}),
    Typed = Table.TransformColumnTypes(RemoveLabel, {{"Score", type number}}),
    Reordered = Table.ReorderColumns(Typed, {"Track", "Type", "Week", "Week Start Date", "Email", "Score"})
in
    Reordered