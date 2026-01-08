-- Migration Script: Legacy System -> New Optimized System
-- Description: Migrates data from temporary/legacy tables to the new normalized structure with Enums and Audit fields.
-- Assumption: Source tables are named with prefix 'legacy_' (e.g., legacy_candidate, legacy_position).
-- Usage: Rename your existing tables to 'legacy_[tablename]' before running this script, or adjust the FROM clauses.

-- A. Enable Extensions if needed (e.g. for UUIDs or fuzzy matching, though not strictly required here)
-- CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

BEGIN;

-- 1. COMPANIES
-- Map old company data.
INSERT INTO COMPANY (id, name, created_at, updated_at)
SELECT 
    id, 
    name, 
    COALESCE(created_at, NOW()), 
    COALESCE(updated_at, NOW())
FROM legacy_company
ON CONFLICT (id) DO NOTHING;

-- Reset Sequence
SELECT setval('company_id_seq', (SELECT MAX(id) FROM COMPANY));


-- 2. INTERVIEW FLOWS & TYPES
-- Assuming flows and types might be static or migrated similarly
INSERT INTO INTERVIEW_FLOW (id, description, created_at)
SELECT id, description, NOW()
FROM legacy_interview_flow
ON CONFLICT (id) DO NOTHING;

INSERT INTO INTERVIEW_TYPE (id, name, description)
SELECT id, name, description
FROM legacy_interview_type
ON CONFLICT (id) DO NOTHING;

SELECT setval('interview_flow_id_seq', (SELECT MAX(id) FROM INTERVIEW_FLOW));
SELECT setval('interview_type_id_seq', (SELECT MAX(id) FROM INTERVIEW_TYPE));


-- 3. EMPLOYEES
-- Transformation: String Role -> Enum Role
INSERT INTO EMPLOYEE (id, company_id, name, email, role, is_active, created_at)
SELECT 
    e.id, 
    e.company_id, 
    e.name, 
    e.email, 
    CASE 
        WHEN UPPER(e.role) IN ('ADMIN', 'ADMINISTRATOR') THEN 'ADMIN'::employee_role_enum
        WHEN UPPER(e.role) IN ('RECRUITER', 'TALENT_ACQUISITION') THEN 'RECRUITER'::employee_role_enum
        WHEN UPPER(e.role) IN ('MANAGER', 'HIRING_MANAGER', 'LEAD') THEN 'HIRING_MANAGER'::employee_role_enum
        ELSE 'INTERVIEWER'::employee_role_enum -- Default fallback
    END,
    COALESCE(e.is_active, TRUE),
    NOW()
FROM legacy_employee e
ON CONFLICT (email) DO NOTHING;

SELECT setval('employee_id_seq', (SELECT MAX(id) FROM EMPLOYEE));


-- 4. INTERVIEW STEPS
INSERT INTO INTERVIEW_STEP (id, interview_flow_id, interview_type_id, name, order_index)
SELECT id, interview_flow_id, interview_type_id, name, order_index
FROM legacy_interview_step
ON CONFLICT (id) DO NOTHING;

SELECT setval('interview_step_id_seq', (SELECT MAX(id) FROM INTERVIEW_STEP));


-- 5. POSITIONS
-- Transformation: String Status/Type -> Enums
INSERT INTO POSITION (
    id, company_id, interview_flow_id, title, description, 
    status, is_visible, location, job_description, requirements, 
    responsibilities, salary_min, salary_max, employment_type, 
    created_at
)
SELECT 
    p.id, p.company_id, p.interview_flow_id, p.title, p.description,
    -- Map Status
    CASE 
        WHEN UPPER(p.status) = 'OPEN' THEN 'OPEN'::position_status_enum
        WHEN UPPER(p.status) = 'CLOSED' THEN 'CLOSED'::position_status_enum
        WHEN UPPER(p.status) = 'DRAFT' THEN 'DRAFT'::position_status_enum
        WHEN UPPER(p.status) = 'ARCHIVED' THEN 'ARCHIVED'::position_status_enum
        ELSE 'PAUSED'::position_status_enum
    END,
    COALESCE(p.is_visible, TRUE),
    p.location, p.job_description, p.requirements, p.responsibilities,
    p.salary_min, p.salary_max,
    -- Map Employment Type
    CASE 
        WHEN UPPER(p.employment_type) LIKE '%FULL%' THEN 'FULL_TIME'::employment_type_enum
        WHEN UPPER(p.employment_type) LIKE '%PART%' THEN 'PART_TIME'::employment_type_enum
        WHEN UPPER(p.employment_type) LIKE '%CONTRACT%' THEN 'CONTRACT'::employment_type_enum
        WHEN UPPER(p.employment_type) LIKE '%INTERN%' THEN 'INTERNSHIP'::employment_type_enum
        WHEN UPPER(p.employment_type) LIKE '%FREE%' THEN 'FREELANCE'::employment_type_enum
        ELSE 'TEMPORARY'::employment_type_enum
    END,
    COALESCE(p.created_at, NOW())
FROM legacy_position p
ON CONFLICT (id) DO NOTHING;

SELECT setval('position_id_seq', (SELECT MAX(id) FROM POSITION));


-- 6. CANDIDATES
-- Basic migration
INSERT INTO CANDIDATE (id, first_name, last_name, email, phone, address, created_at)
SELECT 
    c.id, 
    c.firstName, -- Assuming camelCase in legacy as seen in first Prisma file
    c.lastName, 
    c.email, 
    c.phone, 
    c.address,
    NOW()
FROM legacy_candidate c
ON CONFLICT (email) DO NOTHING;

SELECT setval('candidate_id_seq', (SELECT MAX(id) FROM CANDIDATE));


-- 7. APPLICATIONS
-- Transformation: String Status -> Enum
INSERT INTO APPLICATION (id, position_id, candidate_id, application_date, status, notes, created_at)
SELECT 
    a.id, 
    a.position_id, 
    a.candidate_id, 
    COALESCE(a.application_date, NOW()), 
    CASE 
        WHEN UPPER(a.status) IN ('PENDING', 'NEW') THEN 'PENDING'::application_status_enum
        WHEN UPPER(a.status) IN ('REVIEW', 'REVIEWING') THEN 'REVIEWING'::application_status_enum
        WHEN UPPER(a.status) IN ('INTERVIEW', 'INTERVIEWING') THEN 'INTERVIEWING'::application_status_enum
        WHEN UPPER(a.status) IN ('OFFER', 'OFFERED') THEN 'OFFERED'::application_status_enum
        WHEN UPPER(a.status) IN ('HIRED', 'ACCEPTED') THEN 'HIRED'::application_status_enum
        WHEN UPPER(a.status) IN ('REJECTED', 'DECLINED') THEN 'REJECTED'::application_status_enum
        ELSE 'WITHDRAWN'::application_status_enum
    END,
    a.notes,
    NOW()
FROM legacy_application a
ON CONFLICT (id) DO NOTHING;

SELECT setval('application_id_seq', (SELECT MAX(id) FROM APPLICATION));


-- 8. INTERVIEWS
-- Transformation: Result -> Enum
INSERT INTO INTERVIEW (id, application_id, interview_step_id, employee_id, interview_date, result, score, notes, created_at)
SELECT 
    i.id, 
    i.application_id, 
    i.interview_step_id, 
    i.employee_id, 
    i.interview_date,
    CASE 
        WHEN UPPER(i.result) = 'PASSED' THEN 'PASSED'::interview_result_enum
        WHEN UPPER(i.result) = 'FAILED' THEN 'FAILED'::interview_result_enum
        WHEN UPPER(i.result) IN ('NO_SHOW', 'NOSHOW') THEN 'NO_SHOW'::interview_result_enum
        ELSE 'PENDING'::interview_result_enum
    END,
    i.score,
    i.notes,
    NOW()
FROM legacy_interview i
ON CONFLICT (id) DO NOTHING;

SELECT setval('interview_id_seq', (SELECT MAX(id) FROM INTERVIEW));

-- 9. CANDIDATE DETAILS (Education, etc)
-- If these tables existed
INSERT INTO EDUCATION (institution, title, start_date, end_date, candidate_id)
SELECT institution, title, start_date, end_date, candidate_id
FROM legacy_education;

INSERT INTO WORK_EXPERIENCE (company, position, description, start_date, end_date, candidate_id)
SELECT company, position, description, start_date, end_date, candidate_id
FROM legacy_work_experience;

COMMIT;

-- END OF MIGRATION
