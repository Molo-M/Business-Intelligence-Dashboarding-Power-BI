let
    // 1. Program runs 10 full weeks from ProgramStartDate (Monday of Week 1)
    StartDate = ProgramStartDate,
    EndDate = Date.AddDays(ProgramStartDate, 10 * 7 - 1),
    DayCount = Duration.Days(EndDate - StartDate) + 1,

    // 2. One row per day
    Dates = List.Dates(StartDate, DayCount, #duration(1, 0, 0, 0)),
    ToTable = Table.FromList(Dates, Splitter.SplitByNothing(), {"Date"}),
    Typed = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),

    // 3. Week columns (same formula as fact_Participation, so they always agree)
    AddWeek = Table.AddColumn(Typed, "Week", each
        Number.RoundDown(Duration.Days([Date] - ProgramStartDate) / 7) + 1, Int64.Type),
    AddWeekLabel = Table.AddColumn(AddWeek, "Week Label", each
        "Week " & Text.From([Week]), type text),
    AddWeekStart = Table.AddColumn(AddWeekLabel, "Week Start Date", each
        Date.AddDays(ProgramStartDate, ([Week] - 1) * 7), type date),

    // 4. Month columns: "Aug 2024" for display, 202408 for sorting
    AddMonth = Table.AddColumn(AddWeekStart, "Month", each
        Date.ToText([Date], [Format = "MMM yyyy", Culture = "en-US"]), type text),
    AddMonthSort = Table.AddColumn(AddMonth, "Month Sort", each
        Date.Year([Date]) * 100 + Date.Month([Date]), Int64.Type),

    // 5. Day columns: 1 = Monday ... 7 = Sunday
    AddDayName = Table.AddColumn(AddMonthSort, "Day Name", each
        Date.ToText([Date], [Format = "dddd", Culture = "en-US"]), type text),
    AddDayOfWeek = Table.AddColumn(AddDayName, "Day of Week", each
        Date.DayOfWeek([Date], Day.Monday) + 1, Int64.Type),

    // 6. Classes run Monday to Friday. Used in Phase 3 to count class days.
    AddIsClassDay = Table.AddColumn(AddDayOfWeek, "Is Class Day", each
        if [Day of Week] <= 5 then 1 else 0, Int64.Type)
in
    AddIsClassDay