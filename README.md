# Dare Careers – Learner Progress & Performance Dashboard

Power BI dashboard tracking attendance, participation, assessments and outcomes
for Dare Careers' PowerBI Training and Cloud Training tracks (Aug–Oct 2024 cohort).

## Project status
- [x] Phase 0 – Setup
- [x] Phase 1 – Power Query (data cleaning)
- [x] Phase 2 – Data model
- [x] Phase 3 – DAX measures
- [ ] Phase 4 – Page 1: Overall Performance
- [ ] Phase 5 – Page 2: Learner Insights
- [ ] Phase 6 – Validation & documentation

## Proposed Repo Structure

```
Business-Intelligence-Dashboard/
├── Data/                                  # raw data: never edit by hand
│   ├── Cloud Training/
│   │   ├── Zoom Attendance/
│   │   │   └── Week 1/ … Week 10/         # daily CSVs
│   │   ├── labs_and_quizzes.xlsx
│   │   ├── participant_status.xlsx
│   │   └── participation.xlsx
│   └── PowerBI Training/
│       ├── Zoom Attendance/
│       │   └── Week 1/ … Week 10/
│       ├── Labs & Quizes.xlsx
│       ├── Participation records.xlsx
│       └── Status of Participanat.xlsx
├── Dashboard/
│   └── Dare-Careers-Dashboard.pbip        # Power BI Project (Git-friendly text format)
├── Power Query/                           # exported M code, one file per query
│   ├── fn_ParseDuration.pq
│   ├── fact_Attendance.pq
│   ├── fact_Participation.pq
│   ├── fact_Assessments.pq
│   ├── dim_Learner.pq
│   └── dim_Date.pq
├── DAX/
│   └── measures.md                        # every measure + what it does
├── Docs/
│   ├── data-dictionary.md                 # incl. the format differences between tracks
│   ├── data-model.png
│   └── screenshots/
│       ├── page1-overall-performance.png
│       └── page2-learner-insights.png
├── Project-Description.md
├── README.md
└── .gitignore
```

## Repo structure
- `Data/` – raw source data (never edited by hand)
- `Dashboard/` – Power BI project (.pbip)
- `Power Query/` – exported M code
- `DAX/` – measure definitions
- `Docs/` – data dictionary, model diagram, screenshots

## How to open
1. Clone the repo.
2. Open `Dashboard/Dare-Careers-Dashboard.pbip` in Power BI Desktop.
3. Update the `RootFolder` parameter to your local path to `Data\`, then Refresh.