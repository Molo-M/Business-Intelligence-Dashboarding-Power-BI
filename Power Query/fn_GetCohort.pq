// Returns the cohort name = the first folder directly below RootFolder.
// Example: RootFolder = "C:\...\Data\"
//          Folder Path = "C:\...\Data\Cohort 1 - Aug 2024\Cloud Training\Zoom Attendance\Week 1\"
//          Result      = "Cohort 1 - Aug 2024"
(FolderPath as text) as nullable text =>
let
    IsUnderRoot = Text.StartsWith(Text.Lower(FolderPath), Text.Lower(RootFolder)),
    Relative = if IsUnderRoot then Text.Middle(FolderPath, Text.Length(RootFolder)) else null,
    Cohort = if Relative = null then null else Text.BeforeDelimiter(Relative, "\"),
    Result = if Cohort = null or Cohort = "" then null else Cohort
in
    Result
