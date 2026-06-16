# Enrollment Reporting System — Requirements & Design Document

**Project:** Columbia GS Enrollment Funnel Analytics  
**Prepared by:** Aastha Gade | aastha.rdg@gmail.com  
**Version:** 1.0  
**Date:** June 2025  
**Status:** Sample / Reference Document  

---

## 1. Executive Summary

The School of General Studies Enrollment Management team needs reliable, repeatable reporting on applicant funnel progression, yield rates, and demographic outcomes. This document captures the requirements, data design, and technical specification for a reporting layer built on top of Slate CRM and Salesforce Advisor Link data.

---

## 2. Stakeholder & Requirements Gathering

### 2.1 Stakeholders Identified

| Role | Primary Need |
|---|---|
| Director of Software Dev & Analytics | Accurate, maintainable stored procedures; consistent data quality |
| Enrollment Management Leadership | Term-over-term trend reports; yield and conversion KPIs |
| Admissions Advisors | Applicant status lookup; stale application alerts |
| Dean's Office | Mission-alignment reporting (first-gen %, veteran %, international %) |

### 2.2 Key Questions Asked During Requirements Gathering

- What decisions are you currently making from spreadsheet exports vs. live system data?
- Which Slate fields map to the funnel stages you care about?
- How often do you need this data refreshed — daily, weekly, per-term?
- What does "complete application" mean in your workflow — all materials, or just submitted?
- Are there existing Crystal Report templates we should stay consistent with?

### 2.3 Clarified Objectives (Post-Stakeholder Review)

1. **Funnel visibility** — count applicants at every stage per term, with drop-off rates
2. **Yield reporting** — enrolled / admitted, broken down by program
3. **Demographic tracking** — % first-gen, international, veteran, transfer among enrolled students
4. **Ops alerting** — flag applications stuck in "Complete" > 30 days without a decision
5. **Leadership export** — one-click report callable by term code, exportable to Excel/Crystal

---

## 3. Data Model

### 3.1 Source Systems

| System | Data Provided |
|---|---|
| Technolutions Slate | Applicant records, application status, funnel stage events |
| Salesforce Advisor Link | Advisor assignments, student success flags |
| Internal Warehouse | Normalized copies of above, enriched with term/program lookup tables |

### 3.2 Entity Overview

```
programs ─────────────┐
terms ────────────────┤
decision_types ───────┤──► applications ──► funnel_events
student_types ────────┤         │
                       │         └──► applicants
                       └─────────────────────────────────
```

### 3.3 Key Design Decisions

- **Separate funnel_events table** (event log pattern) rather than status columns on applications — enables point-in-time queries and preserves history if a student withdraws and re-applies
- **Indexed on term, program, and demographic flags** — optimized for the aggregation queries most commonly run by the enrollment team
- **Nullable decision fields** — applications may be in-progress; NULLs are meaningful and should not be filtered out in funnel counts

---

## 4. Reporting Objects Built

### 4.1 Views (read-only, consumable by Crystal Reports / Excel)

| View Name | Purpose |
|---|---|
| `vw_funnel_summary` | Headcount at each stage, % of term total |
| `vw_yield_by_program` | Yield rate (enrolled/admitted) per program per term |
| `vw_demographic_enrolled` | % first-gen, international, veteran, transfer among enrolled |

### 4.2 Stored Procedures (parameterized, for ad-hoc and scheduled reports)

| Procedure | Parameter | Returns |
|---|---|---|
| `get_funnel_drop_off(term_code)` | Term code string | Stage-to-stage attrition counts + % |
| `get_term_enrollment_report(term_code)` | Term code string | Full KPI snapshot per program |
| `flag_stale_applications(days_threshold)` | Int (default 30) | Applications awaiting decision past threshold |

---

## 5. Data Quality & Integrity Controls

| Risk | Control |
|---|---|
| Duplicate Slate records | `slate_id UNIQUE` constraint on applicants table |
| Funnel stages recorded out of order | `event_date` preserved; queries use chronological ordering |
| NULL decision for "in-progress" apps | `flag_stale_applications()` surfaces these proactively |
| Term code mismatches | FK to terms table; procedures RAISE EXCEPTION on invalid term |
| Demographic flag inconsistencies | Boolean flags with NOT NULL DEFAULT FALSE; no ambiguous NULLs |

---

## 6. Assumptions & Open Questions

| # | Assumption / Open Question | Owner |
|---|---|---|
| 1 | Slate exports are refreshed nightly to the warehouse | Engineering |
| 2 | "Enrolled" = student paid deposit and confirmed — need to confirm Slate field | Enrollment Ops |
| 3 | Crystal Reports templates use stored proc output — confirm expected column names | Reporting team |
| 4 | 30-day stale threshold is appropriate — should this vary by term length? | Director of Analytics |

---

## 7. Deliverables

- [x] Normalized PostgreSQL schema (`01_schema.sql`)
- [x] Stored procedures and views (`02_stored_procedures_views.sql`)
- [x] Mock dataset (1,200 records) mirroring Slate export structure
- [x] Python analysis script with matplotlib charts
- [x] HTML analytics dashboard (`dashboard/index.html`)
- [x] This requirements document

---

*This is a sample project demonstrating the type of work I would bring to the Reporting Analyst role at Columbia GS. All data is synthetically generated — no real student records are used.*

*— Aastha Gade*
