# Columbia GS — Enrollment Analytics Sample Project

**Built by:** Aastha Gade &nbsp;|&nbsp; [aastha.rdg@gmail.com](mailto:aastha.rdg@gmail.com) &nbsp;|&nbsp; [LinkedIn](https://linkedin.com/in/aastha-gade-0086a1237)

A sample analytics project built to demonstrate the type of reporting work I'd bring to the **Data Analyst** role at Columbia University School of General Studies.

All data is **synthetically generated** — no real student records are used.

---

## What's Inside

```
columbia-gs-enrollment-analysis/
├── sql/
│   ├── 01_schema.sql                    # Normalized PostgreSQL schema
│   └── 02_stored_procedures_views.sql   # 3 stored procedures + 3 views
├── data/
│   ├── generate_and_analyze.py          # Mock data generator + chart builder
│   ├── mock_enrollment_data.csv         # 1,200 synthetic applicant records
│   └── enrollment_summary_stats.csv     # Aggregate KPIs
├── dashboard/
│   ├── index.html                       # Interactive HTML dashboard
│   └── 01_funnel.png / 02_... / ...    # Charts
├── docs/
│   └── requirements_and_design_doc.md  # Full requirements + design spec
└── README.md
```

---

## What This Covers 
|---|---|
| SQL — stored procedures, functions, views | `02_stored_procedures_views.sql` — 3 SPs, 3 views |
| Relational database design | `01_schema.sql` — normalized schema, FK constraints, indexes |
| Python reporting | `generate_and_analyze.py` — data gen + matplotlib analysis |
| Data quality / integrity | Stale application flagging SP; UNIQUE constraints; NULL handling doc |
| Requirements & process documentation | `docs/requirements_and_design_doc.md` |
| Ad-hoc + routine reporting | Views for routine; parameterized SPs for ad-hoc |
| Crystal Reports / Excel-ready | SP outputs designed as clean tabular result sets |

---

## Key Findings (Mock Data)

- **Biggest funnel leak:** Inquiry → Submission (23% drop) — opportunity for early engagement
- **Highest yield:** Postbaccalaureate (70%) | **Lowest:** Science Certificate (52%)
- **Mission alignment:** 42% transfer, 32% first-gen, 28% international among enrolled students
- **Avg days to decision:** 27 days across all programs

---

## How to Run

```bash
# Install dependencies
pip install pandas numpy matplotlib

# Generate data + charts
python data/generate_and_analyze.py

# View dashboard
open dashboard/index.html

# Load SQL into PostgreSQL
psql -d your_db -f sql/01_schema.sql
psql -d your_db -f sql/02_stored_procedures_views.sql

# Run a stored procedure
SELECT * FROM get_funnel_drop_off('Fall2024');
SELECT * FROM get_term_enrollment_report('Fall2024');
SELECT * FROM flag_stale_applications(30);
```

---


