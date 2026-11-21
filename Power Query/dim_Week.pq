// Program weeks 1..ProgramWeeks. "Week 3" means the 3rd week of a learner's own cohort,
// so one Week slicer works across cohorts that started on different dates.
let
    Weeks = {1..ProgramWeeks},
    ToTable = Table.FromList(Weeks, Splitter.SplitByNothing(), {"Week"}),
    Typed = Table.TransformColumnTypes(ToTable, {{"Week", Int64.Type}}),
    AddLabel = Table.AddColumn(Typed, "Week Label", each "Week " & Text.From([Week]), type text)
in
    AddLabel
