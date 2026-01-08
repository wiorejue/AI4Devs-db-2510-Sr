-- Database Schema Script - Enhanced & Normalized & Indexed
-- Dialect: PostgreSQL
-- Improvements: Added Enums, Audit Fields, Skill Normalization, Integrity Constraints, Performance Indexes

-- 0. Clean up
DROP TABLE IF EXISTS CANDIDATE_SKILL CASCADE;
DROP TABLE IF EXISTS POSITION_SKILL CASCADE;
DROP TABLE IF EXISTS SKILL CASCADE;
DROP TABLE IF EXISTS RESUME CASCADE;
DROP TABLE IF EXISTS WORK_EXPERIENCE CASCADE;
DROP TABLE IF EXISTS EDUCATION CASCADE;
DROP TABLE IF EXISTS INTERVIEW CASCADE;
DROP TABLE IF EXISTS APPLICATION CASCADE;
DROP TABLE IF EXISTS INTERVIEW_STEP CASCADE;
DROP TABLE IF EXISTS POSITION CASCADE;
DROP TABLE IF EXISTS EMPLOYEE CASCADE;
DROP TABLE IF EXISTS CANDIDATE CASCADE;
DROP TABLE IF EXISTS INTERVIEW_TYPE CASCADE;
DROP TABLE IF EXISTS INTERVIEW_FLOW CASCADE;
DROP TABLE IF EXISTS COMPANY CASCADE;

-- Drop Types if exist
DROP TYPE IF EXISTS application_status_enum CASCADE;
DROP TYPE IF EXISTS position_status_enum CASCADE;
DROP TYPE IF EXISTS employment_type_enum CASCADE;
DROP TYPE IF EXISTS interview_result_enum CASCADE;
DROP TYPE IF EXISTS employee_role_enum CASCADE;

-- 1. Enums & Shared Types

CREATE TYPE application_status_enum AS ENUM ('PENDING', 'REVIEWING', 'INTERVIEWING', 'OFFERED', 'REJECTED', 'HIRED', 'WITHDRAWN');
CREATE TYPE position_status_enum AS ENUM ('DRAFT', 'OPEN', 'PAUSED', 'CLOSED', 'ARCHIVED');
CREATE TYPE employment_type_enum AS ENUM ('FULL_TIME', 'PART_TIME', 'CONTRACT', 'FREELANCE', 'INTERNSHIP', 'TEMPORARY');
CREATE TYPE interview_result_enum AS ENUM ('PENDING', 'PASSED', 'FAILED', 'NO_SHOW');
CREATE TYPE employee_role_enum AS ENUM ('ADMIN', 'RECRUITER', 'HIRING_MANAGER', 'INTERVIEWER');

-- 2. Independent Tables & Catalogues

CREATE TABLE COMPANY (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE INTERVIEW_FLOW (
    id SERIAL PRIMARY KEY,
    description VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE INTERVIEW_TYPE (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT
);

CREATE TABLE SKILL (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(100) -- e.g. 'Tech', 'Soft', 'Language'
);

CREATE TABLE CANDIDATE (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(50),
    address VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Dependent Tables

CREATE TABLE EMPLOYEE (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    role employee_role_enum DEFAULT 'INTERVIEWER',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employee_company FOREIGN KEY (company_id) REFERENCES COMPANY(id) ON DELETE CASCADE
);

CREATE TABLE INTERVIEW_STEP (
    id SERIAL PRIMARY KEY,
    interview_flow_id INTEGER NOT NULL,
    interview_type_id INTEGER NOT NULL,
    name VARCHAR(255) NOT NULL,
    order_index INTEGER NOT NULL,
    CONSTRAINT fk_step_flow FOREIGN KEY (interview_flow_id) REFERENCES INTERVIEW_FLOW(id) ON DELETE CASCADE,
    CONSTRAINT fk_step_type FOREIGN KEY (interview_type_id) REFERENCES INTERVIEW_TYPE(id)
);

CREATE TABLE POSITION (
    id SERIAL PRIMARY KEY,
    company_id INTEGER NOT NULL,
    interview_flow_id INTEGER NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status position_status_enum DEFAULT 'DRAFT',
    is_visible BOOLEAN DEFAULT TRUE,
    location VARCHAR(255),
    job_description TEXT,
    requirements TEXT,
    responsibilities TEXT,
    salary_min DECIMAL(15, 2),
    salary_max DECIMAL(15, 2),
    employment_type employment_type_enum,
    benefits TEXT,
    company_description TEXT,
    application_deadline DATE,
    contact_info VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_position_company FOREIGN KEY (company_id) REFERENCES COMPANY(id) ON DELETE CASCADE,
    CONSTRAINT fk_position_flow FOREIGN KEY (interview_flow_id) REFERENCES INTERVIEW_FLOW(id)
);

CREATE TABLE APPLICATION (
    id SERIAL PRIMARY KEY,
    position_id INTEGER NOT NULL,
    candidate_id INTEGER NOT NULL,
    application_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status application_status_enum DEFAULT 'PENDING',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_application_position FOREIGN KEY (position_id) REFERENCES POSITION(id) ON DELETE CASCADE,
    CONSTRAINT fk_application_candidate FOREIGN KEY (candidate_id) REFERENCES CANDIDATE(id) ON DELETE CASCADE,
    CONSTRAINT uq_application_candidate_position UNIQUE (position_id, candidate_id) -- Prevent duplicate applications
);

CREATE TABLE INTERVIEW (
    id SERIAL PRIMARY KEY,
    application_id INTEGER NOT NULL,
    interview_step_id INTEGER NOT NULL,
    employee_id INTEGER NOT NULL,
    interview_date TIMESTAMP,
    result interview_result_enum DEFAULT 'PENDING',
    score INTEGER,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_interview_application FOREIGN KEY (application_id) REFERENCES APPLICATION(id) ON DELETE CASCADE,
    CONSTRAINT fk_interview_step FOREIGN KEY (interview_step_id) REFERENCES INTERVIEW_STEP(id),
    CONSTRAINT fk_interview_employee FOREIGN KEY (employee_id) REFERENCES EMPLOYEE(id)
);

-- 4. Extended Candidate Details

CREATE TABLE EDUCATION (
    id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL,
    institution VARCHAR(100) NOT NULL,
    title VARCHAR(250) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_education_candidate FOREIGN KEY (candidate_id) REFERENCES CANDIDATE(id) ON DELETE CASCADE
);

CREATE TABLE WORK_EXPERIENCE (
    id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL,
    company VARCHAR(100) NOT NULL,
    position VARCHAR(100) NOT NULL,
    description VARCHAR(200),
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_work_candidate FOREIGN KEY (candidate_id) REFERENCES CANDIDATE(id) ON DELETE CASCADE
);

CREATE TABLE RESUME (
    id SERIAL PRIMARY KEY,
    candidate_id INTEGER NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type VARCHAR(50) NOT NULL,
    upload_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_resume_candidate FOREIGN KEY (candidate_id) REFERENCES CANDIDATE(id) ON DELETE CASCADE
);

-- 5. Many-to-Many Relations (Join Tables)

CREATE TABLE CANDIDATE_SKILL (
    candidate_id INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    level INTEGER DEFAULT 1, -- e.g. 1-5
    PRIMARY KEY (candidate_id, skill_id),
    CONSTRAINT fk_cs_candidate FOREIGN KEY (candidate_id) REFERENCES CANDIDATE(id) ON DELETE CASCADE,
    CONSTRAINT fk_cs_skill FOREIGN KEY (skill_id) REFERENCES SKILL(id) ON DELETE CASCADE
);

CREATE TABLE POSITION_SKILL (
    position_id INTEGER NOT NULL,
    skill_id INTEGER NOT NULL,
    PRIMARY KEY (position_id, skill_id),
    CONSTRAINT fk_ps_position FOREIGN KEY (position_id) REFERENCES POSITION(id) ON DELETE CASCADE,
    CONSTRAINT fk_ps_skill FOREIGN KEY (skill_id) REFERENCES SKILL(id) ON DELETE CASCADE
);

-- 6. Indexes for Performance

-- Foreign Keys (Best practice for joins)
CREATE INDEX idx_employee_company_id ON EMPLOYEE(company_id);
CREATE INDEX idx_step_flow_id ON INTERVIEW_STEP(interview_flow_id);
CREATE INDEX idx_position_company_id ON POSITION(company_id);
CREATE INDEX idx_position_flow_id ON POSITION(interview_flow_id);
CREATE INDEX idx_application_position_id ON APPLICATION(position_id);
CREATE INDEX idx_application_candidate_id ON APPLICATION(candidate_id);
CREATE INDEX idx_interview_application_id ON INTERVIEW(application_id);
CREATE INDEX idx_interview_employee_id ON INTERVIEW(employee_id);

-- Candidate Search
CREATE INDEX idx_candidate_email ON CANDIDATE(email);
CREATE INDEX idx_candidate_names ON CANDIDATE(last_name, first_name); -- Composite index for name search

-- Position Filtering
CREATE INDEX idx_position_status ON POSITION(status); -- Filter active jobs
CREATE INDEX idx_position_title ON POSITION(title); -- Keyword search
CREATE INDEX idx_position_location ON POSITION(location); -- Geo-filter

-- Application Management
CREATE INDEX idx_application_date ON APPLICATION(application_date); -- Sorting/Recent
CREATE INDEX idx_application_status ON APPLICATION(status); -- Pipeline view

-- Interview Scheduling
CREATE INDEX idx_interview_date ON INTERVIEW(interview_date); -- Calendar view
CREATE INDEX idx_interview_result ON INTERVIEW(result); -- Analytics

-- 7. Trigger for Automatic Updated_At
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
   NEW.updated_at = NOW();
   RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_candidate_modtime BEFORE UPDATE ON CANDIDATE FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_company_modtime BEFORE UPDATE ON COMPANY FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_employee_modtime BEFORE UPDATE ON EMPLOYEE FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_position_modtime BEFORE UPDATE ON POSITION FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_application_modtime BEFORE UPDATE ON APPLICATION FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
CREATE TRIGGER update_interview_modtime BEFORE UPDATE ON INTERVIEW FOR EACH ROW EXECUTE PROCEDURE update_timestamp();
