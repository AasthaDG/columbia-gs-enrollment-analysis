-- ============================================================
-- Columbia GS Enrollment Management Database Schema
-- Author: Aastha Gade | aastha.rdg@gmail.com
-- Description: Normalized schema modeling the applicant lifecycle
--              from inquiry through enrollment, aligned with
--              Slate CRM and Salesforce Advisor Link workflows.
-- ============================================================

-- -----------------------------------------------
-- LOOKUP / DIMENSION TABLES
-- -----------------------------------------------

CREATE TABLE programs (
    program_id      SERIAL PRIMARY KEY,
    program_code    VARCHAR(20)  NOT NULL UNIQUE,
    program_name    VARCHAR(100) NOT NULL,
    degree_type     VARCHAR(50)  NOT NULL  -- e.g. 'BA', 'Postbaccalaureate', 'Certificate'
);

CREATE TABLE terms (
    term_id         SERIAL PRIMARY KEY,
    term_code       VARCHAR(10)  NOT NULL UNIQUE,  -- e.g. 'Fall2023'
    term_name       VARCHAR(50)  NOT NULL,
    start_date      DATE         NOT NULL,
    end_date        DATE         NOT NULL
);

CREATE TABLE student_types (
    type_id         SERIAL PRIMARY KEY,
    type_code       VARCHAR(30)  NOT NULL UNIQUE,
    type_label      VARCHAR(80)  NOT NULL  -- 'Transfer', 'First-Gen', 'International', 'Veteran', 'Adult Learner'
);

CREATE TABLE decision_types (
    decision_id     SERIAL PRIMARY KEY,
    decision_code   VARCHAR(20)  NOT NULL UNIQUE,
    decision_label  VARCHAR(60)  NOT NULL  -- 'Admitted', 'Denied', 'Waitlisted', 'Deferred', 'Withdrawn'
);

-- -----------------------------------------------
-- CORE APPLICANT TABLE
-- -----------------------------------------------

CREATE TABLE applicants (
    applicant_id        SERIAL PRIMARY KEY,
    slate_id            VARCHAR(36)  NOT NULL UNIQUE,  -- Technolutions Slate GUID
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(150) NOT NULL,
    country_of_origin   VARCHAR(80),
    state_of_residence  VARCHAR(50),
    is_first_gen        BOOLEAN      NOT NULL DEFAULT FALSE,
    is_international    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_veteran          BOOLEAN      NOT NULL DEFAULT FALSE,
    is_transfer         BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------
-- APPLICATION TABLE  (one applicant can apply multiple terms)
-- -----------------------------------------------

CREATE TABLE applications (
    application_id      SERIAL PRIMARY KEY,
    applicant_id        INT          NOT NULL REFERENCES applicants(applicant_id),
    program_id          INT          NOT NULL REFERENCES programs(program_id),
    term_id             INT          NOT NULL REFERENCES terms(term_id),
    app_submitted_date  DATE,
    app_complete_date   DATE,        -- all materials received
    review_complete_date DATE,
    decision_id         INT          REFERENCES decision_types(decision_id),
    decision_date       DATE,
    is_enrolled         BOOLEAN      NOT NULL DEFAULT FALSE,
    enrolled_date       DATE,
    scholarship_offered NUMERIC(10,2),
    created_at          TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------
-- FUNNEL STAGE TRACKING  (point-in-time log)
-- -----------------------------------------------

CREATE TYPE funnel_stage AS ENUM (
    'Inquiry',
    'Started Application',
    'Application Submitted',
    'Application Complete',
    'Under Review',
    'Decision Released',
    'Admitted',
    'Enrolled',
    'Denied',
    'Withdrawn'
);

CREATE TABLE funnel_events (
    event_id        SERIAL PRIMARY KEY,
    application_id  INT          NOT NULL REFERENCES applications(application_id),
    stage           funnel_stage NOT NULL,
    event_date      DATE         NOT NULL,
    notes           TEXT,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------
-- INDEXES FOR REPORTING PERFORMANCE
-- -----------------------------------------------

CREATE INDEX idx_applications_term    ON applications(term_id);
CREATE INDEX idx_applications_program ON applications(program_id);
CREATE INDEX idx_funnel_application   ON funnel_events(application_id);
CREATE INDEX idx_funnel_stage         ON funnel_events(stage);
CREATE INDEX idx_applicant_flags      ON applicants(is_first_gen, is_international, is_veteran, is_transfer);
