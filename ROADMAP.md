# 🚀 HireInn Labs – Product Roadmap

## 📌 Vision

Build an AI-powered Applicant Tracking System (ATS) where HRs can:

* Generate job descriptions using AI
* Publish jobs on a career page
* Analyze resumes using AI
* Manage candidates efficiently
* Schedule interviews with automated emails

---

# 🧱 Phase 0 – Project Setup (✅ Already Done)

* Rails 8 app initialized
* Docker + Kamal setup
* CI/CD pipeline
* Base structure ready

---

# 🧑‍💼 Phase 1 – Authentication & HR System

## Goals

* HR login system
* Secure dashboard access

## Tasks

* [x] Add `devise` gem
* [x] Generate User model
* [X] Add roles (HR/Admin)
* [X] Create authentication flow
* [X] Protect routes

## Output

✅ HR can sign up, log in, log out

---

# 💼 Phase 2 – Job Management (Core Feature) (✅ Done)

## Goals

* HR can create and manage job listings

## Tasks

* [x] Generate Job model
* [x] Fields:

  * title
  * description
  * skills_required
  * experience_required
  * location
  * status (draft/published)
* [x] Build CRUD UI (Hotwire)
* [x] Add dashboard page

## Output

✅ HR can create and publish jobs

---

# 🤖 Phase 3 – AI Job Description Generator (✅ Done)

## Goals

* Generate job descriptions using AI

## Tasks

* [x] Setup OpenRouter API client
* [x] Create service:

  * `Ai::JobDescriptionGenerator`
* [x] Build UI button:

  * "Generate with AI"
* [x] Use Turbo to update description dynamically

## Output

✅ HR inputs key points → AI generates full JD

---

# 🌐 Phase 4 – Career Page (Public) (✅ Done)

## Goals

* Public job listing page

## Tasks

* [x] Create public routes
* [x] Job listing page
* [x] Job detail page
* [x] Apply button

## Output

✅ Candidates can view and apply for jobs

---

# 📄 Phase 5 – Candidate Application System (✅ Done)

## Goals

* Allow candidates to apply with resume

## Tasks

* [x] Create Candidate model
* [x] Create Application model
* [x] Setup Active Storage (resume upload)
* [x] Build apply form:

  * name
  * email
  * phone
  * resume

## Output

✅ Candidates can apply with resume

---

# 🧠 Phase 6 – Resume Parsing (✅ Done)

## Goals

* Extract structured data from resumes

## Tasks

* [x] Use `yomu` for text extraction (HR uploads only)
* [x] Create ResumeParser service
* [x] Extract:

  * name
  * email
  * phone
  * skills
  * education
* [x] Store parsed data

## Output

✅ Resume converted into structured data

---

# 🤖 Phase 7 – AI Resume Analysis (✅ Done)

## Goals

* Match resumes with job descriptions

## Tasks

* [x] Create `Ai::ResumeAnalyzer`
* [x] Generate:

  * match percentage
  * matched skills
  * missing skills
  * experience fit
* [x] Store in `analysis_json (jsonb)`
* [x] Display in UI

## Output

✅ Candidates ranked with AI scoring

---

# ⚙️ Phase 8 – Background Jobs

## Goals

* Process heavy tasks asynchronously

## Tasks

* [ ] Use Solid Queue (Rails 8 default)
* [ ] Create jobs:

  * Resume parsing
  * AI analysis
* [ ] Trigger jobs after resume upload

## Output

✅ Non-blocking AI processing

---

# 📊 Phase 9 – Candidate Management Dashboard

## Goals

* HR can manage applicants

## Tasks

* [ ] Candidate listing UI
* [ ] Filters:

  * match score
  * status
* [ ] Status updates:

  * Applied
  * Shortlisted
  * Rejected

## Output

✅ HR can manage hiring pipeline

---

# 📅 Phase 10 – Interview Scheduling

## Goals

* Schedule interviews and notify candidates

## Tasks

* [ ] Create Interview model
* [ ] Add scheduling UI
* [ ] Generate meeting link (optional)
* [ ] Send email via ActionMailer

## Output

✅ Interview invites sent automatically

---

# 📬 Phase 11 – Email System

## Goals

* Automated communication

## Tasks

* [ ] Setup mailer config
* [ ] Create emails:

  * Application received
  * Interview invite
* [ ] Background delivery

## Output

✅ Automated email workflow

---

# 🔒 Phase 12 – Security & Optimization

## Tasks

* [ ] Add validations
* [ ] Rate limit AI requests
* [ ] Handle API failures
* [ ] Add logging
* [ ] Optimize DB queries

---

# 🚀 Phase 13 – Deployment

## Tasks

* [ ] Setup production DB
* [ ] Configure environment variables
* [ ] Deploy via Kamal
* [ ] Setup domain + SSL

## Output

✅ Live production app

---

# 🌟 Future Enhancements

* [ ] AI auto-shortlisting
* [ ] Resume ranking leaderboard
* [ ] Google Calendar integration
* [ ] Bulk resume upload
* [ ] Candidate chatbot
* [ ] Analytics dashboard

---

# 🧭 Development Strategy

## MVP First Approach

1. Auth
2. Job CRUD
3. Apply flow
4. Resume upload
5. AI analysis

## Then scale features gradually

---

# ⚠️ Important Notes

* AI results are **approximate**, not perfect
* Resume parsing may need refinement
* Keep prompts simple initially
* Monitor API costs

---

# 🏁 End Goal

A **fully functional AI-powered hiring platform** built entirely in Rails 8 with:

* Minimal JS
* Strong backend
* Scalable AI integration

---
