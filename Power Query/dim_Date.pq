let
    // 1. Calendar covers every cohort: from the earliest cohort start
    //    to the Sunday of the final week of the latest cohort
    StartDate = List.Min(stg_Cohorts[Cohort Start Date]),
    EndDate = Date.AddDays(List.Max(stg_Cohorts[Cohort Start Date]), ProgramWeeks * 7 - 1),
    DayCount = Duration.Days(EndDate - StartDate) + 1,

    // 2. One row per day
    Dates = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),

    // 3. Month columns: "Aug 2024" for display, 202408 for sorting
    AddMonth = Table.AddColumn(Typed, "Month", each
        Date.ToText([Date], [Format = "MMM yyyy", Culture = "en-US"]), type text),
    AddMonthSort = Table.AddColumn(AddMonth, "Month Sort", each
        Date.Year([Date]) * 100 + Date.Month([Date]), Int64.Type),

    // 4. Day columns: 1 = Monday ... 7 = Sunday
    AddDayName = Table.AddColumn(AddMonthSort, "Day Name", each
        Date.ToText([Date], [Format = "dddd", Culture = "en-US"]), type text),
    AddDayOfWeek = Table.AddColumn(AddDayName, "Day of Week", each
        Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type)

    // Program weeks now live in dim_Week, because "Week 3" means
    // different calendar dates for different cohorts.
in
    AddDayOfWeek
