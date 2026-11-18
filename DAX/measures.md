# DAX Measures

All measures live in the `_Measures` table and are grouped into four display folders.
Every measure is written to return the correct value in any filter context: the whole
program, a single track or cohort, a week or month, or an individual learner.

## Model reference

| Table | Grain (one row per…) | Key columns used by measures |
|---|---|---|
| `dim_Learner` | learner | `Email`, `Is Graduate`, `Is Certified`, `Is Dropout` |
| `dim_Date` | calendar day (05-Aug-2024 → 13-Oct-2024) | `Date`, `Is Class Day` |
| `fact_Attendance` | learner per class day they joined Zoom | `Minutes`, `Attended` |
| `fact_Participation` | learner per day they participated | (row count) |
| `fact_Assessments` | learner per week per assessment type | `Type`, `Score` |

Relationships: `dim_Learner[Email]` and `dim_Date[Date]` → each fact table (one-to-many, single direction).
`fact_Assessments` joins `dim_Date` on `Week Start Date`.

## Business rules and decisions

1. **Attendance rule:** a learner has *attended* a class only if they spent **more than 30 minutes**
   in the Zoom session (`Minutes > 30`). Exactly 30 minutes does not count. The rule is applied in
   Power Query (`fact_Attendance[Attended]`) and used by every attendance measure, including hours in class.
2. **Class length:** each class runs 6:00–8:00 PM, i.e. **120 minutes**.
3. **Class days:** Monday to Friday, 5 per week, 50 over the 10-week program (`dim_Date[Is Class Day]`).
4. **Dropout:** a learner whose Graduation Status is **Non Graduate**.
5. **Lab completed:** a lab counts as completed only if its **score is above 0**. A score of 0 is treated
   as not submitted. Zeros are still **included** in average scores, as a missed lab lowers a learner's average.
6. **Assessment dates:** labs and quizzes are recorded per week, so each is dated to the **Monday of its week**.
   As a result, Week 9 (30-Sep → 04-Oct) assessments fall under **September** when filtering by month.
7. **Absences:** absent learners have no row in the attendance or participation tables. Rates therefore
   compare what happened against what was possible: `learners × class days`.

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
Number of learners who did not graduate (see rule 4). *Format: whole number.*

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
Share of learners who dropped out. *Format: percentage, 1 decimal.*

---

## Attendance

### Class Days
```dax
Class Days =
-- Number of Mon–Fri class days in the current selection (50 for the whole program, 5 for one week)
SUM ( dim_Date[Is Class Day] )
```
Class days available in the selected period. Used as a denominator. *Format: whole number.*

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
-- Days attended ÷ days they could have attended
DIVIDE ( [Days Attended], [Total Learners] * [Class Days] )
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
-- Share of all available class time (120 min per class day) actually spent in class
VAR ClassMinutesPerDay = 120
RETURN
    DIVIDE (
        [Total Hours in Class] * 60,
        [Total Learners] * [Class Days] * ClassMinutesPerDay
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
-- Days participated ÷ class days available
DIVIDE ( [Days Participated], [Total Learners] * [Class Days] )
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
Total labs completed (see rule 5). Used for Page 2's *Count of Labs*. *Format: whole number.*

### Avg Labs Completed per Learner
```dax
Avg Labs Completed per Learner =
DIVIDE ( [Labs Completed], [Total Learners] )
```
Average number of labs completed per learner, out of 10. *Format: decimal, 2 decimals.*

---

## Validation results

Values checked against independent calculations from the raw source files (no slicers applied).

| Measure | AWS Cloud | Power BI | Total |
|---|---|---|---|
| Total Learners | 40 | 100 | 140 |
| Total Graduations | 33 | 86 | 119 |
| Total Certifications | 24 | 68 | 92 |
| Total Dropouts | 7 | 14 | 21 |
| Graduation Rate | 82.5% | 86.0% | 85.0% |
| Certification Rate | 60.0% | 68.0% | 65.7% |
| Dropout Rate | 17.5% | 14.0% | 15.0% |
| Days Participated | 1,784 | 4,253 | 6,037 |
| Participation Rate | 89.2% | 85.1% | 86.2% |
| Avg Assessment Score | 51.8 | 50.4 | 50.8 |
| Avg Lab Score | 50.9 | 49.8 | 50.1 |
| Avg Quiz Score | 52.8 | 51.0 | 51.5 |
| Labs Completed | 396 | 987 | 1,383 |
| Avg Labs Completed per Learner | 9.90 | 9.87 | 9.88 |
| Class Days | 50 | 50 | 50 |
