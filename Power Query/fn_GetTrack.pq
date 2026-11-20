// Returns the learning track from a file's folder path.
// "...\Cloud Training\..."   -> "AWS Cloud"
// "...\PowerBI Training\..." -> "Power BI"
(FolderPath as text) as nullable text =>
let
    p = Text.Lower(FolderPath),
    Track =
        if Text.Contains(p, "\cloud training\") then "AWS Cloud"
        else if Text.Contains(p, "\powerbi training\") then "Power BI"
        else null
in
    Track
