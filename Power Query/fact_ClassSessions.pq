// One row per class session actually held, per cohort and track.
// A session counts as held when a Zoom attendance file exists for that date.
// Used to work out how many class days each learner COULD have attended.
let
    Source = src_AllFiles,

    // 1. Zoom CSVs only (file information is enough: no CSVs are opened)
    ZoomFiles = Table.SelectRows(Source, each
        [Extension] = ".csv" and Text.Contains([Folder Path], "Zoom Attendance")),

    // 2. Cohort, track, week and date from the path and file name
    AddCohort = Table.AddColumn(ZoomFiles, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddTrack = Table.AddColumn(AddCohort, "Track", each fn_GetTrack([Folder Path]), type text),
    AddWeek = Table.AddColumn(AddTrack, "Week", each
        Number.From(Text.BetweenDelimiters([Folder Path], "Week ", "\")), Int64.Type),
    AddDate = Table.AddColumn(AddWeek, "Date", each
        Date.FromText(Text.Start([Name], 11), [Format = "dd-MMM-yyyy", Culture = "en-US"]), type date),

    // 3. One row per session
    KeepCols = Table.SelectColumns(AddDate, {"Cohort", "Track", "Week", "Date"}),
    Sessions = Table.Distinct(KeepCols)
in
    Sessions
