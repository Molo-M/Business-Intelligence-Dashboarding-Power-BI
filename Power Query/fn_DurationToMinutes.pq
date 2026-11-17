// Converts a Zoom duration to minutes.
// Accepts: text "1:46:00" / "1:46" / "66", a number (66),
// a time value (#time(1,46,0)) or a duration value (#duration(0,1,46,0)).
(DurationValue as any) as nullable number =>
let
    Minutes =
        if DurationValue = null then null

        // Already a number, e.g. 66
        else if Value.Is(DurationValue, type number) then DurationValue

        // A duration value
        else if Value.Is(DurationValue, type duration) then Duration.TotalMinutes(DurationValue)

        // A time value, e.g. 1:46:00 read as a clock time
        else if Value.Is(DurationValue, type time) then
            Time.Hour(DurationValue) * 60 + Time.Minute(DurationValue) + Time.Second(DurationValue) / 60

        // Text: split on ":" and count the pieces
        else
            let
                t = Text.Trim(Text.From(DurationValue)),
                Parts = List.Transform(Text.Split(t, ":"), Number.From)
            in
                if t = "" then null
                else if List.Count(Parts) = 3 then Parts{0} * 60 + Parts{1} + Parts{2} / 60
                else if List.Count(Parts) = 2 then Parts{0} * 60 + Parts{1}
                else Parts{0}
in
    Minutes