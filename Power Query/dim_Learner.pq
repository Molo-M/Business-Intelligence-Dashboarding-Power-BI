let
    // 1. Start from the list of all files
    Source = src_AllFiles,

    // 2. Keep only the two Status workbooks (both file names contain "status")
    Files = Table.SelectRows(Source, each
        [Extension] = ".xlsx"
        and not Text.StartsWith([Name], "~$")
        and Text.Contains(Text.Lower([Name]), "status")),

    // 3. Track from folder path (same logic as before)
    AddTrack = Table.AddColumn(Files, "Track", each
        if Text.Contains([Folder Path], "Cloud Training") then "AWS Cloud"
        else if Text.Contains([Folder Path], "PowerBI Training") then "Power BI"
        else null, type text),

    // 4. Open each workbook and take its first worksheet, whatever it's called
    AddData = Table.AddColumn(AddTrack, "Data", each
        let
            Sheets = Excel.Workbook([Content], true),
            FirstSheet = Table.SelectRows(Sheets, each [Kind] = "Sheet"){0}[Data]
        in
            FirstSheet),

    // 5. Stack both tracks into one table
    KeepCols = Table.SelectColumns(AddData, {"Track", "Data"}),
    Expanded = Table.ExpandTableColumn(KeepCols, "Data",
        {"email", "Graduation Status", "Certification Status"},
        {"Email", "Graduation Status", "Certification Status"}),

    // 6. Tidy text
    Cleaned = Table.TransformColumns(Expanded, {
        {"Email", each Text.Lower(Text.Trim(_)), type text},
        {"Graduation Status", Text.Trim, type text},
        {"Certification Status", Text.Trim, type text}}),

    // 7. MERGE: look up each learner's name from fact_Attendance (like a VLOOKUP)
    Names = Table.Distinct(Table.SelectColumns(fact_Attendance, {"Email", "Name"}), {"Email"}),
    Merged = Table.NestedJoin(Cleaned, {"Email"}, Names, {"Email"}, "Lookup", JoinKind.LeftOuter),
    AddName = Table.ExpandTableColumn(Merged, "Lookup", {"Name"}, {"Name"}),

    // 8. Safety net: if someone never joined Zoom (no name found), show their email instead
    AddLearnerName = Table.AddColumn(AddName, "Learner Name", each
        if [Name] = null or [Name] = "" then [Email] else [Name], type text),
    RemoveName = Table.RemoveColumns(AddLearnerName, {"Name"}),

    // 9. Cohort label, e.g. "Power BI - Aug 2024"
    AddCohort = Table.AddColumn(RemoveName, "Cohort", each
        [Track] & " - " & Date.ToText(ProgramStartDate, [Format = "MMM yyyy", Culture = "en-US"]), type text),

    // 10. Certification type follows the track
    AddCertType = Table.AddColumn(AddCohort, "Certification Type", each
        if [Track] = "AWS Cloud" then "AWS Cloud Certification"
        else if [Track] = "Power BI" then "Power BI Certification"
        else null, type text),

    // 11. Program Status: the program ends on the Friday of Week 10
    ProgramEndDate = Date.AddDays(ProgramStartDate, 10 * 7 - 3),
    AddProgramStatus = Table.AddColumn(AddCertType, "Program Status", each
        if Date.From(DateTime.LocalNow()) > ProgramEndDate then "Completed" else "Ongoing", type text),

    // 12. 1/0 flags for easy counting and rates in DAX
    AddIsGraduate = Table.AddColumn(AddProgramStatus, "Is Graduate", each
        if [Graduation Status] = "Graduate" then 1 else 0, Int64.Type),
    AddIsCertified = Table.AddColumn(AddIsGraduate, "Is Certified", each
        if [Certification Status] = "Certified" then 1 else 0, Int64.Type),
    AddIsDropout = Table.AddColumn(AddIsCertified, "Is Dropout", each
        if [Graduation Status] = "Non Graduate" then 1 else 0, Int64.Type),

    // 13. Put columns in a sensible order
    Reordered = Table.ReorderColumns(AddIsDropout, {
        "Email", "Learner Name", "Track", "Cohort",
        "Graduation Status", "Certification Status", "Certification Type",
        "Program Status", "Is Graduate", "Is Certified", "Is Dropout"})
in
    Reordered