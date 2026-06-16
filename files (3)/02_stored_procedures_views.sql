-- ============================================================
-- Columbia GS Enrollment Reporting: Stored Procedures & Views
-- Author: Aastha Gade | aastha.rdg@gmail.com
-- Description: Reusable reporting objects for enrollment KPIs,
--              funnel analysis, and demographic breakdowns.
--              Mirrors the kind of objects maintained in an
--              enterprise reporting / Slate-connected warehouse.
-- ============================================================


-- ============================================================
-- VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- V1: Enrollment Funnel Summary by Term
--     Aggregates headcount at each funnel stage per term.
--     Used for leadership dashboards and term-over-term comparison.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_funnel_summary AS
SELECT
    t.term_name,
    t.term_code,
    fe.stage,
    COUNT(DISTINCT fe.application_id)          AS applicant_count,
    ROUND(
        COUNT(DISTINCT fe.application_id) * 100.0
        / NULLIF(SUM(COUNT(DISTINCT fe.application_id)) OVER (PARTITION BY t.term_id), 0),
    2)                                          AS pct_of_term_total
FROM funnel_events   fe
JOIN applications    a  ON fe.application_id = a.application_id
JOIN terms           t  ON a.term_id         = t.term_id
GROUP BY t.term_name, t.term_code, t.term_id, fe.stage
ORDER BY t.term_code, fe.stage;


-- ------------------------------------------------------------
-- V2: Yield Rate by Program and Term
--     Yield = Enrolled / Admitted.  Critical KPI for GS
--     enrollment management — surfaces which programs convert
--     admitted students and which are losing them post-offer.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_yield_by_program AS
SELECT
    t.term_name,
    p.program_name,
    p.degree_type,
    COUNT(*)                                                          AS total_applications,
    COUNT(*) FILTER (WHERE a.decision_id = (
        SELECT decision_id FROM decision_types WHERE decision_code = 'ADMITTED'))
                                                                      AS admitted,
    COUNT(*) FILTER (WHERE a.is_enrolled = TRUE)                      AS enrolled,
    ROUND(
        COUNT(*) FILTER (WHERE a.is_enrolled = TRUE) * 100.0
        / NULLIF(COUNT(*) FILTER (WHERE a.decision_id = (
            SELECT decision_id FROM decision_types WHERE decision_code = 'ADMITTED')), 0),
    2)                                                                AS yield_rate_pct
FROM applications a
JOIN programs     p ON a.program_id = p.program_id
JOIN terms        t ON a.term_id    = t.term_id
GROUP BY t.term_name, p.program_name, p.degree_type
ORDER BY t.term_name, yield_rate_pct DESC;


-- ------------------------------------------------------------
-- V3: Demographic Breakdown of Enrolled Students
--     Supports GS's core mission reporting: how many first-gen,
--     international, veteran, and transfer students are we
--     actually enrolling each term?
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_demographic_enrolled AS
SELECT
    t.term_name,
    COUNT(*)                                                        AS total_enrolled,
    COUNT(*) FILTER (WHERE ap.is_first_gen    = TRUE)              AS first_gen_count,
    COUNT(*) FILTER (WHERE ap.is_international = TRUE)             AS international_count,
    COUNT(*) FILTER (WHERE ap.is_veteran       = TRUE)             AS veteran_count,
    COUNT(*) FILTER (WHERE ap.is_transfer      = TRUE)             AS transfer_count,
    ROUND(COUNT(*) FILTER (WHERE ap.is_first_gen    = TRUE) * 100.0 / NULLIF(COUNT(*),0), 1) AS first_gen_pct,
    ROUND(COUNT(*) FILTER (WHERE ap.is_international = TRUE) * 100.0 / NULLIF(COUNT(*),0), 1) AS international_pct,
    ROUND(COUNT(*) FILTER (WHERE ap.is_veteran       = TRUE) * 100.0 / NULLIF(COUNT(*),0), 1) AS veteran_pct,
    ROUND(COUNT(*) FILTER (WHERE ap.is_transfer      = TRUE) * 100.0 / NULLIF(COUNT(*),0), 1) AS transfer_pct
FROM applications a
JOIN applicants   ap ON a.applicant_id = ap.applicant_id
JOIN terms        t  ON a.term_id      = t.term_id
WHERE a.is_enrolled = TRUE
GROUP BY t.term_name
ORDER BY t.term_name;


-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- ------------------------------------------------------------
-- SP1: get_funnel_drop_off
--      Returns stage-to-stage drop-off rates for a given term.
--      Pinpoints exactly WHERE in the funnel GS is losing
--      applicants — e.g. high drop between 'Admitted' → 'Enrolled'
--      signals a yield problem; high drop at 'Application Complete'
--      → 'Under Review' may signal a processing bottleneck.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_funnel_drop_off(p_term_code VARCHAR)
RETURNS TABLE (
    stage_from      TEXT,
    stage_to        TEXT,
    count_from      BIGINT,
    count_to        BIGINT,
    drop_off_count  BIGINT,
    drop_off_pct    NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_term_id INT;
BEGIN
    SELECT term_id INTO v_term_id
    FROM terms WHERE term_code = p_term_code;

    IF v_term_id IS NULL THEN
        RAISE EXCEPTION 'Term code % not found', p_term_code;
    END IF;

    RETURN QUERY
    WITH stage_counts AS (
        SELECT
            fe.stage,
            COUNT(DISTINCT fe.application_id) AS cnt,
            -- Assign numeric order to stages for sequential comparison
            CASE fe.stage
                WHEN 'Inquiry'                  THEN 1
                WHEN 'Started Application'      THEN 2
                WHEN 'Application Submitted'    THEN 3
                WHEN 'Application Complete'     THEN 4
                WHEN 'Under Review'             THEN 5
                WHEN 'Decision Released'        THEN 6
                WHEN 'Admitted'                 THEN 7
                WHEN 'Enrolled'                 THEN 8
                ELSE 99
            END AS stage_order
        FROM funnel_events   fe
        JOIN applications     a  ON fe.application_id = a.application_id
        WHERE a.term_id = v_term_id
          AND fe.stage NOT IN ('Denied', 'Withdrawn')
        GROUP BY fe.stage
    ),
    ranked AS (
        SELECT stage, cnt, stage_order,
               LEAD(stage)       OVER (ORDER BY stage_order) AS next_stage,
               LEAD(cnt)         OVER (ORDER BY stage_order) AS next_cnt
        FROM stage_counts
    )
    SELECT
        r.stage::TEXT,
        r.next_stage::TEXT,
        r.cnt,
        r.next_cnt,
        (r.cnt - r.next_cnt)                                         AS drop_off_count,
        ROUND((r.cnt - r.next_cnt) * 100.0 / NULLIF(r.cnt, 0), 2)  AS drop_off_pct
    FROM ranked r
    WHERE r.next_stage IS NOT NULL
    ORDER BY r.stage_order;
END;
$$;


-- ------------------------------------------------------------
-- SP2: get_term_enrollment_report
--      Master enrollment snapshot for a given term.
--      Returns one row per program with all key metrics.
--      Designed to feed Crystal Reports / Excel pivot exports.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_term_enrollment_report(p_term_code VARCHAR)
RETURNS TABLE (
    program_name        VARCHAR,
    degree_type         VARCHAR,
    total_applied       BIGINT,
    total_complete      BIGINT,
    total_admitted      BIGINT,
    total_enrolled      BIGINT,
    yield_rate_pct      NUMERIC,
    avg_days_to_decision NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_term_id   INT;
    v_admit_id  INT;
BEGIN
    SELECT term_id     INTO v_term_id  FROM terms          WHERE term_code    = p_term_code;
    SELECT decision_id INTO v_admit_id FROM decision_types WHERE decision_code = 'ADMITTED';

    RETURN QUERY
    SELECT
        p.program_name,
        p.degree_type,
        COUNT(*)                                                                   AS total_applied,
        COUNT(*) FILTER (WHERE a.app_complete_date IS NOT NULL)                   AS total_complete,
        COUNT(*) FILTER (WHERE a.decision_id = v_admit_id)                        AS total_admitted,
        COUNT(*) FILTER (WHERE a.is_enrolled = TRUE)                               AS total_enrolled,
        ROUND(
            COUNT(*) FILTER (WHERE a.is_enrolled = TRUE) * 100.0
            / NULLIF(COUNT(*) FILTER (WHERE a.decision_id = v_admit_id), 0), 2)   AS yield_rate_pct,
        ROUND(AVG(
            a.decision_date - a.app_complete_date
        ) FILTER (WHERE a.decision_date IS NOT NULL AND a.app_complete_date IS NOT NULL), 1)
                                                                                   AS avg_days_to_decision
    FROM applications a
    JOIN programs     p ON a.program_id = p.program_id
    WHERE a.term_id = v_term_id
    GROUP BY p.program_name, p.degree_type
    ORDER BY total_enrolled DESC;
END;
$$;


-- ------------------------------------------------------------
-- SP3: flag_stale_applications
--      Identifies applications stuck in 'Application Complete'
--      for more than N days without a decision — a data quality
--      / ops issue Alessio's team would actively monitor.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION flag_stale_applications(p_days_threshold INT DEFAULT 30)
RETURNS TABLE (
    application_id      INT,
    applicant_name      TEXT,
    email               VARCHAR,
    program_name        VARCHAR,
    term_name           VARCHAR,
    app_complete_date   DATE,
    days_waiting        INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        a.application_id,
        (ap.first_name || ' ' || ap.last_name)::TEXT  AS applicant_name,
        ap.email,
        p.program_name,
        t.term_name,
        a.app_complete_date,
        (CURRENT_DATE - a.app_complete_date)::INT      AS days_waiting
    FROM applications a
    JOIN applicants   ap ON a.applicant_id = ap.applicant_id
    JOIN programs     p  ON a.program_id   = p.program_id
    JOIN terms        t  ON a.term_id      = t.term_id
    WHERE a.app_complete_date IS NOT NULL
      AND a.decision_id       IS NULL
      AND (CURRENT_DATE - a.app_complete_date) > p_days_threshold
    ORDER BY days_waiting DESC;
END;
$$;
