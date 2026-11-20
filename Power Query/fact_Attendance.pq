let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the Zoom CSVs (ignore the Excel files)
    ZoomFiles = Table.SelectRows(Source, each
        [Extension] = ".csv" and Text.Contains([Folder Path], "Zoom Attendance")),

    // 3. Cohort and Track come from the folder path
    AddCohort = Table.AddColumn(ZoomFiles, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddTrack = Table.AddColumn(AddCohort, "Track", each fn_GetTrack([Folder Path]), type text),

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

    // 7. Drop the file-info columns and stack all the small tables into one
    KeepCols = Table.SelectColumns(AddData, {"Cohort", "Track", "Week", "Date", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data",
        {"Name", "Email", "Join Time", "Leave Time", "Duration", "Role"}),

    // 8. Keep learners only (excludes hosts/co-hosts if any appear)
    OnlyParticipants = Table.SelectRows(Expanded, each [Role] = "Participant"),

    // 9. Tidy text: trim spaces, lowercase emails so they match other files
    Cleaned = Table.TransformColumns(OnlyParticipants, {
        {"Name", Text.Trim, type text},
        {"Email", each Text.Lower(Text.Trim(_)), type text}}),

    // 10. Learner Key = one enrolment: the same email could appear in a future cohort or another track
    AddKey = Table.AddColumn(Cleaned, "Learner Key", each
        [Cohort] & "|" & [Track] & "|" & [Email], type text),

    // 11. Convert Duration to minutes using our function
    AddMinutes = Table.AddColumn(AddKey, "Minutes", each fn_DurationToMinutes([Duration]), type number),

    // 12. Convert join/leave times (handles both "06:02 PM" and "18:09")
    Typed = Table.TransformColumnTypes(AddMinutes,
        {{"Join Time", type time}, {"Leave Time", type time}}, "en-US"),

    // 13. One row per learner per day (adds up minutes if someone dropped and rejoined)
    Grouped = Table.Group(Typed, {"Learner Key", "Cohort", "Track", "Week", "Date", "Email", "Name"}, {
        {"Join Time", each List.Min([Join Time]), type time},
        {"Leave Time", each List.Max([Leave Time]), type time},
        {"Minutes", each List.Sum([Minutes]), type number}}),

    // 14. The project rule: attended only if MORE than 30 minutes
    AddAttended = Table.AddColumn(Grouped, "Attended", each [Minutes] > 30, type logical),

    // 15. Share of the 120-minute class attended (capped at 100%)
    AddClassPct = Table.AddColumn(AddAttended, "Class Time %", each
        List.Min({[Minutes] / 120, 1}), Percentage.Type)
in
    AddClassPct
