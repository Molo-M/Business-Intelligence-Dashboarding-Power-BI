# Data Dictionary

This document describes every data source and every table in the Dare Careers dashboard:
where the data comes from, what each column means, and how it was prepared.

**Contents**

1. [Folder layout](#1-folder-layout)
2. [Raw source files](#2-raw-source-files)
3. [Differences between the two tracks](#3-differences-between-the-two-tracks)
4. [Model tables](#4-model-tables)
5. [Relationships](#5-relationships)
6. [Parameters, helper queries and functions](#6-parameters-helper-queries-and-functions)
7. [Data quality notes](#7-data-quality-notes)
8. [Adding a new cohort](#8-adding-a-new-cohort)

---

## 1. Folder layout

```
Data/
└── Cohort 1 - Aug 2024/              ← one folder per cohort (folder name = cohort name)
    ├── Cloud Training/               ← AWS Cloud track
    │   ├── Zoom Attendance/
    │   │   └── Week 1/ … Week 10/    ← one CSV per class day, e.g. 05-Aug-2024.csv
    │   ├── labs_and_quizzes.xlsx
    │   ├── participant_status.xlsx
    │   └── participation.xlsx
    └── PowerBI Training/             ← Power BI track
        ├── Zoom Attendance/
        │   └── Week 1/ … Week 10/
        ├── Labs & Quizes.xlsx
        ├── Participation records.xlsx
        └── Status of Participanat.xlsx
```

The cohort, track, week and class date are **not stored inside the files**. They are read from the
folder and file names:

| Information | Where it comes from | Example |
|---|---|---|
| Cohort | First folder under `Data/` | `Cohort 1 - Aug 2024` |
| Track | Track folder name | `Cloud Training` → **AWS Cloud**, `PowerBI Training` → **Power BI** |
| Week | `Week N` folder name | `Week 3` → **3** |
| Class date | First 11 characters of the Zoom file name | `05-Aug-2024.csv` → **05 Aug 2024** |

---

## 2. Raw source files

### Zoom attendance (CSV, one file per class day)

| Column | Meaning |
|---|---|
| Name | Learner's full name |
| Email | Learner's email address (used to identify the learner) |
| Join Time | Time the learner joined the Zoom session |
| Leave Time | Time the learner left |
| Duration | Time spent in the session (format differs by track, see section 3) |
| Role | `Participant` for learners |

### Labs & Quizzes (Excel, one workbook per track)

Two sheets, **Labs** and **Quizzes**, each with one row per learner:

| Column | Meaning |
|---|---|
| email | Learner's email address |
| Week 1 … Week 10 | Score for that week's lab or quiz, from 0 to 100 |

### Participation (Excel, one workbook per track)

One row per class day:

| Column | Meaning |
|---|---|
| Date | Class date, stored as text, e.g. `05-Aug-2024` |
| Participants | Comma-separated **names** (not emails) of everyone who participated that day |

### Status (Excel, one workbook per track)

One row per learner:

| Column | Meaning | Values |
|---|---|---|
| email | Learner's email address | |
| Graduation Status | Whether the learner graduated | `Graduate`, `Non Graduate` |
| Certification Status | Whether the learner was certified | `Certified`, `Not Certified` |

---

## 3. Differences between the two tracks

The two tracks hold the same kind of information but format it differently. Power Query handles every
difference, so **the raw files are never edited**.

| | Power BI track | AWS Cloud track | How it's handled |
|---|---|---|---|
| Learners | 100 | 40 | |
| Email format | `emilyjohnson@example.com` | `james.williams@msc.com` | Emails are lowercased and trimmed |
| Zoom Duration | Text `1:46:00` (hours:minutes:seconds) | Whole minutes, e.g. `66` | `fn_DurationToMinutes` converts both to minutes |
| Zoom times | 12-hour, e.g. `06:02 PM` | 24-hour, e.g. `18:09` | Converted with an English (US) locale, which reads both |
| Labs & Quizzes file | `Labs & Quizes.xlsx` | `labs_and_quizzes.xlsx` | Found by the word "quiz" in the file name |
| Participation file | `Participation records.xlsx` | `participation.xlsx` | Found by the word "participation" |
| Status file | `Status of Participanat.xlsx` | `participant_status.xlsx` | Found by the word "status" |
| Participation sheet name | `Sheet1` | `Participation` | The first sheet is read, whatever its name |

---

## 4. Model tables

The model follows a **star schema**: *dimension* tables describe **who** and **when**, and *fact* tables
record **what happened**. Columns marked *hidden* are used by relationships and calculations but are not
shown to report users.

### `dim_Learner`: one row per learner enrolment (140 rows)

| Column | Type | Description |
|---|---|---|
| Learner Key | Text | *Hidden.* Unique ID: `Cohort | Track | Email`. Lets the same person appear in a future cohort or another track |
| Email | Text | Learner's email (lowercased) |
| Learner Name | Text | Full name, looked up from the Zoom files. Shows the email if the learner never joined Zoom |
| Cohort | Text | Cohort name, from the cohort folder. Sorted by Cohort Start Date |
| Track | Text | `Power BI` or `AWS Cloud` |
| Cohort Start Date | Date | *Hidden.* Monday of the week of the cohort's first class |
| Cohort End Date | Date | *Hidden.* Friday of the final program week |
| Program Status | Text | `Completed` once the cohort end date has passed, otherwise `Ongoing` |
| Graduation Status | Text | `Graduate` / `Non Graduate`, from the Status file |
| Certification Status | Text | `Certified` / `Not Certified`. Shown as **Learner Status** on the dashboard |
| Certification Type | Text | `AWS` or `Power BI`, based on the track |
| Classes Held | Whole number | Class sessions held for the learner's cohort and track |
| Classes Attended | Whole number | Classes attended for **more than 30 minutes** |
| Weeks Attended | Whole number | Number of different weeks with at least one attended class |
| Last Week Attended | Whole number | Latest week with an attended class (0 if none) |
| Has Incomplete Attendance | True/False | True if Classes Attended is less than Classes Held |
| Is Graduate | 1/0 | *Hidden.* 1 if Graduate. Summed by the graduation measures |
| Is Certified | 1/0 | *Hidden.* 1 if Certified |
| Is Dropout | 1/0 | *Hidden.* 1 if Non Graduate **and** Not Certified **and** Has Incomplete Attendance, once the program has completed |

### `dim_Date`: one row per calendar day (70 rows for the current cohort)

Covers every day from the earliest cohort start to the end of the latest cohort's final week.

| Column | Type | Description |
|---|---|---|
| Date | Date | The calendar day. Marked as the model's date table |
| Month | Text | e.g. `Aug 2024`. Used by the Month slicer. Sorted by Month Sort |
| Month Sort | Whole number | *Hidden.* e.g. `202408`, so months sort in date order |
| Day Name | Text | e.g. `Monday`. Sorted by Day of Week |
| Day of Week | Whole number | *Hidden.* 1 = Monday … 7 = Sunday |

### `dim_Week`: one row per program week (10 rows)

| Column | Type | Description |
|---|---|---|
| Week | Whole number | Program week, 1 to 10, counted from each cohort's own start date |
| Week Label | Text | e.g. `Week 3`. Used by the Week slicer. Sorted by Week |

### `fact_Attendance`: one row per learner per class they joined

A learner who did not join a class has **no row** for that day.

| Column | Type | Description |
|---|---|---|
| Learner Key | Text | *Hidden.* Links to `dim_Learner` |
| Cohort, Track | Text | *Hidden.* Kept for checking; filtering uses `dim_Learner` |
| Week | Whole number | *Hidden.* From the `Week N` folder. Links to `dim_Week` |
| Date | Date | *Hidden.* From the file name. Links to `dim_Date` |
| Email, Name | Text | *Hidden.* As recorded by Zoom |
| Join Time | Time | Earliest join time that day |
| Leave Time | Time | Latest leave time that day |
| Minutes | Decimal | Total minutes in the session (added up if the learner left and rejoined) |
| Attended | True/False | **True only if Minutes is more than 30** (the project's attendance rule) |
| Class Time % | Percentage | Minutes ÷ 120-minute class, capped at 100% |

### `fact_Participation`: one row per learner per day they participated (6,037 rows)

| Column | Type | Description |
|---|---|---|
| Learner Key | Text | *Hidden.* Found by matching Cohort + Track + Name to `dim_Learner` |
| Cohort, Track | Text | *Hidden.* |
| Week | Whole number | *Hidden.* Calculated from the date and the cohort start date |
| Date | Date | *Hidden.* Class date |
| Email | Text | *Hidden.* Looked up from `dim_Learner` |
| Name | Text | *Hidden.* Name as written in the participation file |

### `fact_Assessments`: one row per learner per week per assessment type (2,800 rows)

| Column | Type | Description |
|---|---|---|
| Learner Key | Text | *Hidden.* Links to `dim_Learner` |
| Cohort, Track | Text | *Hidden.* |
| Type | Text | `Lab` or `Quiz` (from the sheet name) |
| Week | Whole number | *Hidden.* Program week. Links to `dim_Week` |
| Week Start Date | Date | *Hidden.* Monday of that program week. Links to `dim_Date` |
| Email | Text | *Hidden.* |
| Score | Decimal | *Hidden.* Score from 0 to 100. A 0 is treated as "not submitted" when counting completed labs |

### `fact_ClassSessions`: one row per class held, per cohort and track (100 rows)

Built from the Zoom file names only. Used to work out how many classes each learner **could** have
attended, so that attendance and participation rates are fair across cohorts and tracks. The whole
table is hidden.

| Column | Type | Description |
|---|---|---|
| Cohort | Text | Cohort name |
| Track | Text | Track |
| Week | Whole number | Program week. Links to `dim_Week` |
| Date | Date | Class date. Links to `dim_Date` |

### `_Measures`

Holds all DAX measures, grouped into five display folders. It has no data and no relationships; each
measure refers directly to the tables it needs. See [`DAX/measures.md`](../DAX/measures.md).

---

## 5. Relationships

All relationships are **one-to-many** and filter in **one direction**: from the dimension to the fact table.

| From (one) | To (many) |
|---|---|
| `dim_Learner[Learner Key]` | `fact_Attendance[Learner Key]` |
| `dim_Learner[Learner Key]` | `fact_Participation[Learner Key]` |
| `dim_Learner[Learner Key]` | `fact_Assessments[Learner Key]` |
| `dim_Date[Date]` | `fact_Attendance[Date]` |
| `dim_Date[Date]` | `fact_Participation[Date]` |
| `dim_Date[Date]` | `fact_Assessments[Week Start Date]` |
| `dim_Date[Date]` | `fact_ClassSessions[Date]` |
| `dim_Week[Week]` | `fact_Attendance[Week]` |
| `dim_Week[Week]` | `fact_Participation[Week]` |
| `dim_Week[Week]` | `fact_Assessments[Week]` |
| `dim_Week[Week]` | `fact_ClassSessions[Week]` |

---

## 6. Parameters, helper queries and functions

These are used during data preparation only and are not loaded into the report.

| Name | Kind | Purpose |
|---|---|---|
| `RootFolder` | Parameter (text) | Full path to the repo's `Data\` folder, ending with a backslash. The only setting to change on a new computer |
| `ProgramWeeks` | Parameter (number) | Length of the program in weeks (10) |
| `src_AllFiles` | Query | Lists every file under `RootFolder`. The starting point of every other query |
| `stg_Cohorts` | Query | One row per cohort with its start date, end date and Program Status |
| `fn_DurationToMinutes` | Function | Converts a Zoom duration (`1:46:00`, `66`, or a time value) to minutes |
| `fn_GetCohort` | Function | Returns the cohort name from a file's folder path |
| `fn_GetTrack` | Function | Returns `Power BI` or `AWS Cloud` from a file's folder path |

The M code for every query is in the [`Power Query/`](../Power%20Query/) folder.

---

## 7. Data quality notes

| Observation | Impact and handling |
|---|---|
| Participation lists **names**, not emails | Names are matched to learners by cohort, track and name. All 140 learners matched; no names were left unmatched |
| No learner appears in both tracks | Learner Key still includes the track, so the model stays correct if that changes |
| Every Power BI learner attended all 50 classes for more than 30 minutes | Power BI attendance rate is 100%. The rule is still applied, and it matters for AWS Cloud |
| Some sessions were **exactly 30 minutes** (e.g. one AWS Cloud learner on 05-Aug-2024) | Counted as **not attended**, because the rule requires *more than* 30 minutes |
| 24 lab scores and 13 quiz scores are 0 | A 0 lab is treated as not submitted (not counted as completed) but is kept in averages |
| No missing values in scores or statuses | No rows were removed |
| Assessments are recorded per week, not per day | Each is dated to the Monday of its week; Week 9 (30 Sep – 4 Oct) therefore counts as September |
| File name typos (e.g. "Participanat", "Quizes") | Left as they are; files are found by keyword rather than exact name |

---

## 8. Adding a new cohort

1. Create a new folder under `Data/`, e.g. `Data/Cohort 2 - Jan 2025/`.
2. Inside it, add `Cloud Training/` and/or `PowerBI Training/` with the same layout as Cohort 1:
   a `Zoom Attendance` folder with `Week 1` … `Week 10` sub-folders, plus the three Excel files.
3. Keep the Zoom file names in the `dd-MMM-yyyy.csv` format, and keep "quiz", "participation" and
   "status" in the Excel file names.
4. Open the report and click **Refresh**.

The new cohort then appears in the Cohort slicer and in every chart. Its start date, program status,
week numbers and attendance rates are worked out automatically.
