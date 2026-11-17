let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the two Participation workbooks (both names contain "participation")
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "participation")),

    // 3. Track from folder path
    AddTrack = Table.AddColumn(Files, "Track", each
        if Text.Contains([Folder Path], "Cloud Training") then "AWS Cloud"
        else if Text.Contains([Folder Path], "PowerBI Training") then "Power BI"
        else null, type text),

    // 4. Open each workbook's first sheet (sheet names differ: "Sheet1" vs "Participation")
    AddData = Table.AddColumn(AddTrack, "Data", each
        let
            Sheets = Excel.Workbook([Content], true),
            FirstSheet = Table.SelectRows(Sheets, each [Kind] = "Sheet"){0}[Data]
        in
            FirstSheet),
    KeepCols = Table.SelectColumns(AddData, {"Track", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data", {"Date", "Participants"}),

    // 5. Date is stored as text like "05-Aug-2024". This also copes if Excel
    //    ever stores it as a real date instead.
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

    // 7. SPLIT INTO ROWS: one row per name in the list
    KeepCols2 = Table.SelectColumns(AddNames, {"Track", "Date", "Name"}),
    OneRowPerName = Table.ExpandListColumn(KeepCols2, "Name"),
    Typed = Table.TransformColumnTypes(OneRowPerName, {{"Name", type text}}),

    // 8. Safety: if a name appears twice on the same day, count it once
    NoDupes = Table.Distinct(Typed, {"Track", "Date", "Name"}),

    // 9. MERGE on Track AND Name to find the email in dim_Learner
    Merged = Table.NestedJoin(NoDupes, {"Track", "Name"},
        dim_Learner, {"Track", "Learner Name"}, "Lookup", JoinKind.LeftOuter),
    AddEmail = Table.ExpandTableColumn(Merged, "Lookup", {"Email"}, {"Email"}),

    // 10. Week number from the date: days since Week 1's Monday, divided by 7
    AddWeek = Table.AddColumn(AddEmail, "Week", each
        Number.RoundDown(Duration.Days([Date] - ProgramStartDate) / 7) + 1, Int64.Type),

    // 11. Column order
    Reordered = Table.ReorderColumns(AddWeek, {"Track", "Week", "Date", "Email", "Name"})
in
    Reordered