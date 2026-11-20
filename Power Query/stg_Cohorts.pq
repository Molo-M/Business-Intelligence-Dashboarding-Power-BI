// One row per cohort, worked out from the Zoom file names (no CSVs are opened).
// Cohort Start Date = Monday of the week of the cohort's first class.
// Not loaded into the report: other queries look up cohort dates from here.
let
    Source = src_AllFiles,

    // 1. Zoom CSVs only
    ZoomFiles = Table.SelectRows(Source, each
        [Extension] = ".csv" and Text.Contains([Folder Path], "Zoom Attendance")),

    // 2. Cohort from the folder path, class date from the file name
    AddCohort = Table.AddColumn(ZoomFiles, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddDate = Table.AddColumn(AddCohort, "Date", each
        Date.FromText(Text.Start([Name], 11), [Format = "dd-MMM-yyyy", Culture = "en-US"]), type date),

    // 3. First class date per cohort
    Grouped = Table.Group(AddDate, {"Cohort"}, {
        {"First Class Date", each List.Min([Date]), type date}}),

    // 4. Start = Monday of that week; End = Friday of the final program week
    AddStart = Table.AddColumn(Grouped, "Cohort Start Date", each
        Date.StartOfWeek([First Class Date], Day.Monday), type date),
    AddEnd = Table.AddColumn(AddStart, "Cohort End Date", each
        Date.AddDays([Cohort Start Date], ProgramWeeks * 7 - 3), type date),

    // 5. Completed once today is past the end date
    AddStatus = Table.AddColumn(AddEnd, "Program Status", each
        if Date.From(DateTime.LocalNow()) > [Cohort End Date] then "Completed" else "Ongoing", type text),

    Result = Table.RemoveColumns(AddStatus, {"First Class Date"})
in
    Result
