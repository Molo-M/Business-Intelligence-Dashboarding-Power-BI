# DAX Measures

All measures live in the `_Measures` table and are grouped into five display folders.
Every measure is written to return the correct value in any filter context: all cohorts,
a single cohort or track, a week or month, or an individual learner.

## Model reference

| Table | Grain (one row per…) | Key columns used by measures |
|---|---|---|
| `dim_Learner` | learner enrolment (cohort + track + email) | `Learner Key`, `Cohort`, `Track`, `Is Graduate`, `Is Certified`, `Is Dropout` |
| `dim_Date` | calendar day (covers every cohort) | `Date`, `Month` |
| `dim_Week` | program week (1–10) | `Week`, `Week Label` |
| `fact_Attendance` | learner per class day they joined Zoom | `Minutes`, `Attended` |
| `fact_Participation` | learner per day they participated | (row count) |
| `fact_Assessments` | learner per week per assessment type | `Type`, `Score` |
| `fact_ClassSessions` | class session held, per cohort and track | `Cohort`, `Track` |

Relationships (all one-to-many, single direction):

- `dim_Learner[Learner Key]` → `fact_Attendance`, `fact_Participation`, `fact_Assessments`
- `dim_Date[Date]` → `fact_Attendance[Date]`, `fact_Participation[Date]`, `fact_ClassSessions[Date]`, `fact_Assessments[Week Start Date]`
- `dim_Week[Week]` → `fact_Attendance`, `fact_Participation`, `fact_Assessments`, `fact_ClassSessions`

## Business rules and decisions

1. **Cohorts and tracks:** the data is one cohort (Aug 2024) with two learning tracks, Power BI and AWS Cloud.
   Each cohort has its own folder directly under `Data/`, with one sub-folder per track. Adding a cohort means
   adding a folder with the same layout; no query or measure changes are needed.
2. **Learner Key:** a learner is identified by `Cohort | Track | Email`, so the same person can appear in a
   future cohort or a second track without breaking the model.
3. **Cohort dates:** a cohort starts on the Monday of the week of its first Zoom class and runs for
   `ProgramWeeks` (10) weeks. Program Status is *Completed* once the Friday of the final week has passed.
4. **Attendance rule:** a learner has *attended* a class only if they spent **more than 30 minutes**
   in the Zoom session (`Minutes > 30`). Exactly 30 minutes does not count. This rule is used by every
   attendance measure, including hours in class, and by the dropout rule.
5. **Class length:** each class runs 6:00–8:00 PM, i.e. **120 minutes**.
6. **Classes held:** a class session counts as held for a cohort and track when a Zoom attendance file
   exists for that date (`fact_ClassSessions`). Rates compare what happened against what was possible:
   `learners × sessions held`, worked out separately for each cohort and track.
7. **Dropout (data provider's rule):** a learner is a dropout only if **all three** conditions are met:
   - Graduation Status is **Non Graduate**, and
   - Certification Status is **Not Certified**, and
   - they have **incomplete attendance**: they did not attend (more than 30 minutes, see rule 4) at least
     one class held for their cohort and track. This covers both no-shows and sessions of 30 minutes or less
     (`Classes Attended < Classes Held`).

   Dropouts are only counted once the cohort's program has completed.
   Calculated in Power Query: `dim_Learner[Has Incomplete Attendance]` → `dim_Learner[Is Dropout]`.
8. **Certification Type:** **AWS** for the AWS Cloud track and **Power BI** for the Power BI track.
9. **Lab completed:** a lab counts as completed only if its **score is above 0**. A score of 0 is treated
   as not submitted. Zeros are still **included** in average scores.
10. **Assessment dates:** labs and quizzes are recorded per week, so each is dated to the **Monday of its
    program week** for its cohort. When filtering by month, Week 9 (30-Sep → 04-Oct) assessments therefore
    fall under **September**.
11. **Weeks vs months:** the Week slicer uses `dim_Week` (program week, relative to each cohort's start);
    the Month slicer uses `dim_Date` (calendar month).
12. **At-risk learners:** a learner shows a warning sign for each of: Attendance Rate **below 75%**,
    Participation Rate **below 75%**, and average assessment score **below 45**. The score threshold sits
    near the bottom quarter of learners (overall average 50.8); 50 would flag over 40% of learners.
    All three thresholds are variables at the top of the `At-Risk Flags` measure and can be changed
    if Dare Careers has an official pass mark or attendance requirement.

---

## Learners & Outcomes

### Total Learners
```dax
Total Learners =
COUNTROWS ( dim_Learner )
```
Number of enrolled learners in the current selection. *Format: whole number.*

### Total Graduations
```dax
Total Graduations =
SUM ( dim_Learner[Is Graduate] )
```
Number of learners who graduated. *Format: whole number.*

### Total Certifications
```dax
Total Certifications =
SUM ( dim_Learner[Is Certified] )
```
Number of learners who achieved certification. *Format: whole number.*

### Total Dropouts
```dax
Total Dropouts =
SUM ( dim_Learner[Is Dropout] )
```
Number of learners who meet all three dropout conditions (see rule 7). *Format: whole number.*

### Graduation Rate
```dax
Graduation Rate =
DIVIDE ( [Total Graduations], [Total Learners] )
```
Share of learners who graduated. *Format: percentage, 1 decimal.*

### Certification Rate
```dax
Certification Rate =
DIVIDE ( [Total Certifications], [Total Learners] )
```
Share of learners who achieved certification. *Format: percentage, 1 decimal.*

### Dropout Rate
```dax
Dropout Rate =
DIVIDE ( [Total Dropouts], [Total Learners] )
```
Share of learners who dropped out (see rule 7). *Format: percentage, 1 decimal.*

---

## Attendance

### Possible Learner Days
```dax
Possible Learner Days =
-- For each cohort and track in the current selection:
-- learners enrolled × class sessions actually held (in the selected weeks/months)
SUMX (
    SUMMARIZE ( dim_Learner, dim_Learner[Cohort], dim_Learner[Track] ),
    VAR CurrentCohort = dim_Learner[Cohort]
    VAR CurrentTrack = dim_Learner[Track]
    VAR Learners = CALCULATE ( COUNTROWS ( dim_Learner ) )
    VAR Sessions =
        CALCULATE (
            COUNTROWS ( fact_ClassSessions ),
            fact_ClassSessions[Cohort] = CurrentCohort,
            fact_ClassSessions[Track] = CurrentTrack
        )
    RETURN
        Learners * Sessions
)
```
The number of learner-days that could have been attended. Denominator for the attendance and
participation rates. Replaces the earlier `Class Days` measure, which only worked for a single cohort.
*Format: whole number.*

### Days Attended
```dax
Days Attended =
-- Learner-days where the learner stayed MORE than 30 minutes
CALCULATE (
    COUNTROWS ( fact_Attendance ),
    fact_Attendance[Attended] = TRUE ()
)
```
Number of learner-days that meet the attendance rule. *Format: whole number.*

### Attendance Rate
```dax
Attendance Rate =
-- Days attended ÷ days that could have been attended
DIVIDE ( [Days Attended], [Possible Learner Days] )
```
Share of possible class days that learners attended. Used on Page 2. *Format: percentage, 1 decimal.*

### Total Hours in Class
```dax
Total Hours in Class =
-- Only sessions that pass the 30-minute rule count as time in class
DIVIDE (
    CALCULATE ( SUM ( fact_Attendance[Minutes] ), fact_Attendance[Attended] = TRUE () ),
    60
)
```
Total hours spent in attended classes. *Format: decimal, 1 decimal.*

### Avg Hours per Learner
```dax
Avg Hours per Learner =
DIVIDE ( [Total Hours in Class], [Total Learners] )
```
Average hours in class per learner. *Format: decimal, 1 decimal.*

### Avg Class Time %
```dax
Avg Class Time % =
-- Share of all available class time (120 min per session) actually spent in class
VAR ClassMinutesPerDay = 120
RETURN
    DIVIDE (
        [Total Hours in Class] * 60,
        [Possible Learner Days] * ClassMinutesPerDay
    )
```
Average percentage of total class time attended. Used for Page 1's *Average Attendance*.
*Format: percentage, 1 decimal.*

---

## Participation

### Days Participated
```dax
Days Participated =
COUNTROWS ( fact_Participation )
```
Number of learner-days with recorded participation. *Format: whole number.*

### Participation Rate
```dax
Participation Rate =
-- Days participated ÷ days that could have been attended
DIVIDE ( [Days Participated], [Possible Learner Days] )
```
Share of possible class days on which learners participated. *Format: percentage, 1 decimal.*

---

## Assessments

### Avg Assessment Score
```dax
Avg Assessment Score =
AVERAGE ( fact_Assessments[Score] )
```
Average score across all labs and quizzes, out of 100. *Format: decimal, 1 decimal.*

### Avg Lab Score
```dax
Avg Lab Score =
CALCULATE ( [Avg Assessment Score], fact_Assessments[Type] = "Lab" )
```
Average lab score. *Format: decimal, 1 decimal.*

### Avg Quiz Score
```dax
Avg Quiz Score =
CALCULATE ( [Avg Assessment Score], fact_Assessments[Type] = "Quiz" )
```
Average quiz score. *Format: decimal, 1 decimal.*

### Labs Completed
```dax
Labs Completed =
-- A lab counts as completed only if it scored above 0
CALCULATE (
    COUNTROWS ( fact_Assessments ),
    fact_Assessments[Type] = "Lab",
    fact_Assessments[Score] > 0
)
```
Total labs completed (see rule 9). Used for Page 2's *Count of Labs*. *Format: whole number.*

### Avg Labs Completed per Learner
```dax
Avg Labs Completed per Learner =
DIVIDE ( [Labs Completed], [Total Learners] )
```
Average number of labs completed per learner, out of 10. *Format: decimal, 2 decimals.*

---

## Learner Insights

### At-Risk Flags
```dax
At-Risk Flags =
-- Number of warning signs (0–3) for ONE learner; blank on totals and group rows
VAR AttendanceThreshold = 0.75
VAR ParticipationThreshold = 0.75
VAR ScoreThreshold = 45
RETURN
    IF (
        HASONEVALUE ( dim_Learner[Learner Key] ),
        INT ( [Attendance Rate] < AttendanceThreshold )
            + INT ( [Participation Rate] < ParticipationThreshold )
            + INT ( [Avg Assessment Score] < ScoreThreshold )
    )
```
How many at-risk signs a learner shows in the current selection (see rule 12). Used to sort and
colour the Page 2 learner table. *Format: whole number.*

---

## Validation results

Cohort 1 – Aug 2024, no slicers applied. Values checked against independent calculations
from the raw source files and against the Power BI QA page.

| Measure | AWS Cloud | Power BI | Total |
|---|---|---|---|
| Total Learners | 40 | 100 | 140 |
| Total Graduations | 33 | 86 | 119 |
| Total Certifications | 24 | 68 | 92 |
| Learners meeting dropout conditions 1 + 2 (Non Graduate and Not Certified) | 7 | 14 | 21 |
| Total Dropouts (all three conditions) |  7 | 0 | 7 |
| Graduation Rate | 82.5% | 86.0% | 85.0% |
| Certification Rate | 60.0% | 68.0% | 65.7% |
| Dropout Rate | 17.5% | 0.0% | 5.0% |
| Possible Learner Days | 2,000 | 5,000 | 7,000 |
| Days Attended | 1,585 | 5,000 | 6,585 |
| Attendance Rate | 79.3% | 100.0% | 94.1% |
| Total Hours in Class | 1,813.0 | 8,752.7 | 10,565.7 |
| Avg Class Time % | 45.3% | 87.5% | 75.5% |
| Days Participated | 1,784 | 4,253 | 6,037 |
| Participation Rate | 89.2% | 85.1% | 86.2% |
| Avg Assessment Score | 51.8 | 50.4 | 50.8 |
| Avg Lab Score | 50.9 | 49.8 | 50.1 |
| Avg Quiz Score | 52.8 | 51.0 | 51.5 |
| Labs Completed | 396 | 987 | 1,383 |
| Avg Labs Completed per Learner | 9.90 | 9.87 | 9.88 |

Filter check: with `dim_Week[Week Label]` = Week 1, `Possible Learner Days` = 700 (140 learners × 5 sessions).

Power BI has 0 dropouts because every Power BI learner attended all 50 classes for more than 30 minutes,
so none has incomplete attendance. All 7 AWS Cloud learners who are Non Graduate and Not Certified had incomplete attendance, so all 7 are dropouts.

### Page 2 checks

| Selection | Labs Completed |
|---|---|
| No filters | 1,383 |
| Month = Aug 2024 (Weeks 1–4) | 555 |
| Month = Sep 2024 (Weeks 5–9) | 692 |
| Month = Oct 2024 (Week 10) | 136 |
| Week = Week 1 | 140 |

| Learner | Participation Rate | Avg Lab Score | Avg Quiz Score | Avg Assessment Score | Labs Completed |
|---|---|---|---|---|---|
| James Williams (AWS Cloud) | 90.0% | 57.5 | 52.0 | 54.8 | 10 |
| Emily Johnson (Power BI) | 92.0% | 58.8 | 41.2 | 50.0 | 10 |
