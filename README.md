# HireInn Labs

AI-assisted hiring workflow built with Rails 8 for creating jobs, publishing a public careers page, collecting applications, parsing resumes, and generating AI-backed hiring insights.

## Overview

HireInn Labs is an ATS-style Rails application designed for HR teams and hiring managers who want a faster path from job creation to candidate review.

The product currently supports:

- HR authentication with Devise
- dashboard metrics for jobs and applications
- AI-assisted job description generation
- draft-to-published job workflow
- public careers page and role detail pages
- candidate application flow with resume upload
- applicant confirmation emails sent asynchronously
- resume parsing for HR-uploaded resumes
- AI resume matching and scoring against a job

## Why It’s Interesting

This project combines classic Rails CRUD with AI-enhanced workflows in a way that is practical for an internal recruiting tool:

- AI helps draft structured job descriptions instead of replacing HR review
- published jobs flow directly into a public-facing careers experience
- candidate data is stored in relational models with attached resumes
- resume parsing and AI scoring turn unstructured uploads into reviewable hiring data
- background mail delivery keeps the application flow responsive

## Core Workflow

1. HR signs in and creates a job.
2. HR can use AI to generate a job description, responsibilities, requirements, benefits, and skills.
3. HR reviews the draft and publishes it.
4. The role becomes visible on the public careers page.
5. A candidate applies with personal details and a resume.
6. The application is saved and the applicant receives a styled confirmation email.
7. HR uploads candidate resumes to the resume parser and runs AI matching against the job.
8. Match scores, experience fit, strengths, gaps, and analysis are shown inside the dashboard.

## Feature Set

### HR Dashboard

- authenticated dashboard with job/application trends
- job listing and search
- individual job detail pages
- publish confirmation flow from draft to public listing

### AI Job Description Generator

- OpenRouter-backed job description generation
- structured output for:
  - role overview
  - responsibilities
  - requirements
  - benefits
  - skills
- edge-case handling for fresher and sub-year experience roles

### Public Careers Experience

- public route for published jobs only
- careers listing page
- public job detail page
- job application form with resume attachment

### Application Handling

- candidates are normalized by email
- applications are linked to both candidate and job
- resumes are stored with Active Storage
- applicant confirmation email is sent using Action Mailer + Sidekiq

### Resume Parsing and AI Matching

- bulk resume upload for HR users
- text extraction powered by `yomu`
- parsed fields include:
  - name
  - email
  - phone
  - skills
  - education
- AI resume analysis produces:
  - match score
  - strengths
  - missing skills
  - experience fit
  - structured analysis JSON

## Tech Stack

### Backend

- Ruby 3.3
- Rails 8.1
- PostgreSQL
- Devise
- Active Storage
- Sidekiq

### Frontend

- ERB templates
- Hotwire Turbo
- Stimulus
- Sass via `cssbundling-rails`
- PostCSS + Autoprefixer

### AI / Parsing

- OpenRouter for job-description and resume-analysis workflows
- `yomu` for resume text extraction

### Infrastructure / Ops

- Dockerfile included
- Kamal deployment config present
- Sidekiq initializer configured via `REDIS_URL`
- production PostgreSQL can be provisioned through Aiven
- production Redis can be provisioned through Upstash

## Project Structure

```text
app/
  controllers/          Request flows for HR, careers, applications, dashboard
  mailers/              Applicant confirmation mailers
  models/               Users, jobs, applications, candidates, parsed resumes
  services/             Resume parsing and AI service objects
  services/ai/          OpenRouter-backed generators/analyzers
  views/                HR dashboard, careers pages, mail templates, shared UI
  javascript/           Turbo/Stimulus behaviors
  assets/stylesheets/   Premium dashboard and public UI styling
config/
  environments/         Mailer, Sidekiq, environment-specific app config
  initializers/         Sidekiq, Devise, filters, assets
db/
  migrate/              Schema evolution for jobs, candidates, applications, resumes
test/
  controllers/          Request-level tests
  models/               Model-level tests
```

## Data Model Snapshot

### `User`

- authenticated HR/admin account
- owns many jobs

### `Job`

- draft/published/archived status
- AI metadata
- public slug
- salary, experience, location, employment type
- has many applications
- has many uploaded resumes for matching

### `Candidate`

- normalized by email
- stores applicant identity details
- reused across applications where appropriate

### `Application`

- belongs to a job and candidate
- stores cover letter, status, parsed metadata
- holds the public resume attachment

### `JobResume`

- HR-uploaded resume for parsing/matching workflows
- stores parsed fields and AI analysis output

## Local Setup

### Prerequisites

- Ruby `3.3.x`
- PostgreSQL
- Node.js + Yarn
- Redis `7+`

Important:

- Sidekiq 8 requires Redis 6 or newer
- the default development database config expects a local PostgreSQL user:
  - username: `rails`
  - password: `password`

### Install

```bash
bundle install
yarn install
cp .env.example .env
bin/rails db:create db:migrate
```

### Start the App

Run Redis first, then start the Rails app, CSS watcher, and Sidekiq worker:

```bash
redis-server
bin/dev
```

`bin/dev` starts:

- Rails server
- Sass/PostCSS watcher
- Sidekiq worker

App URL:

- `http://localhost:3000`

## Environment Variables

Use `.env` in development. The project already includes `dotenv-rails`.

### Required for AI

```env
OPEN_ROUTER_API=your_openrouter_api_key
OPEN_ROUTER_AI_MODEL=your_preferred_model
```

### Required for Email

```env
MAILER_FROM="HireInn Labs <notifications@yourdomain.com>"
APP_HOST=localhost
APP_PORT=3000
APP_PROTOCOL=http

SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=localhost
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

### Required for Background Jobs

```env
REDIS_URL=redis://127.0.0.1:6379/0
```

## Production Services

The app is wired to use environment variables in production, so managed services can be swapped in without changing application code.

### PostgreSQL

- Recommended hosted provider: Aiven for PostgreSQL
- Set the Aiven connection string as:

```env
DATABASE_URL=postgres://...
```

### Redis

- Recommended hosted provider: Upstash Redis
- Use the Upstash Redis endpoint for:
  - Sidekiq
  - Redis-backed cache store
  - Action Cable

```env
REDIS_URL=rediss://...
```

## Running Tests

```bash
bin/rails test
```

If PostgreSQL is not running or accessible, Rails tests will fail before execution because the app depends on the configured database.

## Current Technical Status

### Implemented

- authentication and role-backed HR area
- job CRUD and dashboard
- AI-assisted JD generation
- publish-to-careers workflow
- public careers browsing
- candidate applications with resume upload
- styled applicant confirmation emails
- Sidekiq-backed asynchronous mail delivery
- resume parsing
- AI match analysis for uploaded resumes

### In Progress / Worth Improving Next

- stronger automated test coverage across jobs, publishing, and AI flows
- Sidekiq monitoring UI or admin dashboard
- richer candidate/application management filters
- background processing for resume parsing and AI matching
- production-ready Redis/Postgres provisioning notes
- better AI output validation beyond current sanitization rules

## Notes for Reviewers

If you are evaluating the repository quickly, the best files to inspect are:

- [app/controllers/jobs_controller.rb](app/controllers/jobs_controller.rb)
- [app/services/ai/job_description_generator.rb](app/services/ai/job_description_generator.rb)
- [app/controllers/applications_controller.rb](app/controllers/applications_controller.rb)
- [app/mailers/career_application_mailer.rb](app/mailers/career_application_mailer.rb)
- [app/controllers/job_resumes_controller.rb](app/controllers/job_resumes_controller.rb)
- [app/views/jobs/show.html.erb](app/views/jobs/show.html.erb)

These capture the main hiring workflow from job creation to publishing, application intake, and AI-assisted review.

## Screens and UX Direction

The UI uses a premium dark hiring-dashboard style with gold accents across:

- dashboard analytics
- job authoring
- job publishing flow
- resume review
- careers and email surfaces

The intent is to make the product feel more like a polished internal hiring workspace than a default admin panel.

## Deployment

The repository includes:

- `Dockerfile`
- Kamal deployment config under `.kamal/`
- production environment configuration in `config/environments/production.rb`

Before deploying, make sure production has:

- PostgreSQL configured
- Redis 6+ configured for Sidekiq
- SMTP credentials configured
- OpenRouter credentials configured if AI generation is required

## License

No explicit license is currently declared in the repository. Add one before public distribution if this project is intended to be open source.
