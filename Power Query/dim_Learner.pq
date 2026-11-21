let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the Status workbooks (both file names contain "status")
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "status")),

    // 3. Cohort and Track from the folder path
    AddCohort = Table.AddColumn(Files, "Cohort", each fn_GetCohort([Folder Path]), type text),
    AddTrack = Table.AddColumn(AddCohort, "Track", each fn_GetTrack([Folder Path]), type text),

    // 4. Open each workbook and take its first worksheet, whatever it's called
    AddData = Table.AddColumn(AddTrack, "Data", each
        let
            Sheets = Excel.Workbook([Content], true),
            FirstSheet = Table.SelectRows(Sheets, each [Kind] = "Sheet"){0}[Data]
        in
            FirstSheet),

    // 5. Stack all tracks and cohorts into one table
    KeepCols = Table.SelectColumns(AddData, {"Cohort", "Track", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data",
        {"email", "Graduation Status", "Certification Status"},
        {"Email", "Graduation Status", "Certification Status"}),

    // 6. Tidy text
    Cleaned = Table.TransformColumns(Expanded, {
        {"Email", each Text.Lower(Text.Trim(_)), type text},
        {"Graduation Status", Text.Trim, type text},
        {"Certification Status", Text.Trim, type text}}),

    // 7. Learner Key = one enrolment (cohort + track + email). This is the model's key.
    AddKey = Table.AddColumn(Cleaned, "Learner Key", each
        [Cohort] & "|" & [Track] & "|" & [Email], type text),

    // 8. MERGE: look up each learner's name from fact_Attendance
    Names = Table.Distinct(Table.SelectColumns(fact_Attendance, {"Learner Key", "Name"}), {"Learner Key"}),
    MergedNames = Table.NestedJoin(AddKey, {"Learner Key"}, Names, {"Learner Key"}, "NameLookup", JoinKind.LeftOuter),
    AddName = Table.ExpandTableColumn(MergedNames, "NameLookup", {"Name"}, {"Name"}),

    // 9. Safety net: if someone never joined Zoom (no name found), show their email instead
    AddLearnerName = Table.AddColumn(AddName, "Learner Name", each
        if [Name] = null or [Name] = "" then [Email] else [Name], type text),
    RemoveName = Table.RemoveColumns(AddLearnerName, {"Name"}),

    // 10. Cohort dates and Program Status from stg_Cohorts
    MergedCohort = Table.NestedJoin(RemoveName, {"Cohort"}, stg_Cohorts, {"Cohort"}, "CohortInfo", JoinKind.LeftOuter),
    AddCohortInfo = Table.ExpandTableColumn(MergedCohort, "CohortInfo",
        {"Cohort Start Date", "Cohort End Date", "Program Status"}),

    // 11. Certification type follows the track
    AddCertType = Table.AddColumn(AddCohortInfo, "Certification Type", each
        if [Track] = "AWS Cloud" then "AWS"
        else if [Track] = "Power BI" then "Power BI"
        else null, type text),

    // 12. Classes held for the learner's cohort and track (from fact_ClassSessions)
    SessionCounts = Table.Group(fact_ClassSessions, {"Cohort", "Track"}, {
        {"Classes Held", each Table.RowCount(_), Int64.Type}}),
    MergedSessions = Table.NestedJoin(AddCertType, {"Cohort", "Track"},
        SessionCounts, {"Cohort", "Track"}, "SessionInfo", JoinKind.LeftOuter),
    AddClassesHeld = Table.ExpandTableColumn(MergedSessions, "SessionInfo", {"Classes Held"}),

    // 13. Attendance summary per learner, using only classes that pass the 30-minute rule
    AttendedRows = Table.SelectRows(fact_Attendance, each [Attended] = true),
    AttendanceSummary = Table.Group(AttendedRows, {"Learner Key"}, {
        {"Classes Attended", each Table.RowCount(_), Int64.Type},
        {"Weeks Attended", each List.Count(List.Distinct([Week])), Int64.Type},
        {"Last Week Attended", each List.Max([Week]), Int64.Type}}),
    MergedAttendance = Table.NestedJoin(AddClassesHeld, {"Learner Key"},
        AttendanceSummary, {"Learner Key"}, "AttInfo", JoinKind.LeftOuter),
    AddAttendance = Table.ExpandTableColumn(MergedAttendance, "AttInfo",
        {"Classes Attended", "Weeks Attended", "Last Week Attended"}),

    // 14. A learner who never attended has no summary row: show 0, not blank
    FillZeros = Table.ReplaceValue(AddAttendance, null, 0, Replacer.ReplaceValue,
        {"Classes Held", "Classes Attended", "Weeks Attended", "Last Week Attended"}),
    TypedCounts = Table.TransformColumnTypes(FillZeros, {
        {"Cohort Start Date", type date}, {"Cohort End Date", type date}, {"Program Status", type text},
        {"Classes Held", Int64.Type}, {"Classes Attended", Int64.Type},
        {"Weeks Attended", Int64.Type}, {"Last Week Attended", Int64.Type}}),

    // 15. INCOMPLETE ATTENDANCE: the learner did not "attend" (more than 30 minutes)
    //     at least one class that was held for their cohort and track.
    //     This covers both no-shows and sessions of 30 minutes or less.
    //     Alternatives:
    //       a whole week with no attended class:   [Weeks Attended] < ProgramWeeks
    //       stopped attending before final week:   [Last Week Attended] < ProgramWeeks
    AddIncomplete = Table.AddColumn(TypedCounts, "Has Incomplete Attendance", each
        [Classes Attended] < [Classes Held], type logical),

    // 16. 1/0 flags for easy counting and rates in DAX
    AddIsGraduate = Table.AddColumn(AddIncomplete, "Is Graduate", each
        if [Graduation Status] = "Graduate" then 1 else 0, Int64.Type),
    AddIsCertified = Table.AddColumn(AddIsGraduate, "Is Certified", each
        if [Certification Status] = "Certified" then 1 else 0, Int64.Type),

    // 17. DROPOUT: ALL three conditions must be true (data provider's rule),
    //     and only once the cohort's program has finished.
    AddIsDropout = Table.AddColumn(AddIsCertified, "Is Dropout", each
        if [Program Status] = "Completed"
            and [Graduation Status] = "Non Graduate"
            and [Certification Status] = "Not Certified"
            and [Has Incomplete Attendance]
        then 1 else 0, Int64.Type),

    // 18. Column order
    Reordered = Table.ReorderColumns(AddIsDropout, {
        "Learner Key", "Email", "Learner Name", "Cohort", "Track",
        "Cohort Start Date", "Cohort End Date", "Program Status",
        "Graduation Status", "Certification Status", "Certification Type",
        "Classes Held", "Classes Attended", "Weeks Attended", "Last Week Attended",
        "Has Incomplete Attendance", "Is Graduate", "Is Certified", "Is Dropout"})
in
    Reordered
