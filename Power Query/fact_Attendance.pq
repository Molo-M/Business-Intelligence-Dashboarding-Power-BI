let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the Zoom CSVs (ignore the Excel files)
    ZoomFiles = Table.SelectRows(Source, each
        [Extension] = ".csv" and Text.Contains([Folder Path], "Zoom Attendance")),

    // 3. Track comes from the folder path
    AddTrack = Table.AddColumn(ZoomFiles, "Track", each
        if Text.Contains([Folder Path], "Cloud Training") then "AWS Cloud"
        else if Text.Contains([Folder Path], "PowerBI Training") then "Power BI"
        else null, type text),

    // 4. Week number comes from the "Week N" folder name
    AddWeek = Table.AddColumn(AddTrack, "Week", each
        Number.From(Text.BetweenDelimiters([Folder Path], "Week ", "\")), Int64.Type),

    // 5. Date comes from the first 11 characters of the file name, e.g. "05-Aug-2024"
    AddDate = Table.AddColumn(AddWeek, "Date", each
        Date.FromText(Text.Start([Name], 11), [Format = "dd-MMM-yyyy", Culture = "en-US"]), type date),

    // 6. Open each CSV (the "Content" column) into a small table
    AddData = Table.AddColumn(AddDate, "Data", each
        Table.PromoteHeaders(
            Csv.Document([Content], [Delimiter = ",", Encoding = 65001, QuoteStyle = QuoteStyle.Csv]),
            [PromoteAllScalars = true])),

    // 7. Drop the file-info columns and stack all 100 small tables into one
    KeepCols = Table.SelectColumns(AddData, {"Track", "Week", "Date", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data",
        {"Name", "Email", "Join Time", "Leave Time", "Duration", "Role"}),

    // 8. Keep learners only (excludes hosts/co-hosts if any appear)
    OnlyParticipants = Table.SelectRows(Expanded, each [Role] = "Participant"),

    // 9. Tidy text: trim spaces, lowercase emails so they match other files
    Cleaned = Table.TransformColumns(OnlyParticipants, {
        {"Name", Text.Trim, type text},
        {"Email", each Text.Lower(Text.Trim(_)), type text}}),

    // 10. Convert Duration to minutes using our function
    AddMinutes = Table.AddColumn(Cleaned, "Minutes", each fn_DurationToMinutes([Duration]), type number),

    // 11. Convert join/leave times (handles both "06:02 PM" and "18:09")
    Typed = Table.TransformColumnTypes(AddMinutes,
        {{"Join Time", type time}, {"Leave Time", type time}}, "en-US"),

    // 12. One row per learner per day (adds up minutes if someone dropped and rejoined)
    Grouped = Table.Group(Typed, {"Track", "Week", "Date", "Email", "Name"}, {
        {"Join Time", each List.Min([Join Time]), type time},
        {"Leave Time", each List.Max([Leave Time]), type time},
        {"Minutes", each List.Sum([Minutes]), type number}}),

    // 13. The project rule: attended only if MORE than 30 minutes
    AddAttended = Table.AddColumn(Grouped, "Attended", each [Minutes] > 30, type logical),

    // 14. Share of the 120-minute class attended (capped at 100%)
    AddClassPct = Table.AddColumn(AddAttended, "Class Time %", each
        List.Min({[Minutes] / 120, 1}), Percentage.Type)
in
    AddClassPct