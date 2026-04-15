# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_14_093000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "applications", force: :cascade do |t|
    t.bigint "candidate_id", null: false
    t.text "cover_letter"
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "parsed_at"
    t.jsonb "parsed_data", default: {}, null: false
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id"], name: "index_applications_on_candidate_id"
    t.index ["job_id", "candidate_id"], name: "index_applications_on_job_id_and_candidate_id", unique: true
    t.index ["job_id"], name: "index_applications_on_job_id"
  end

  create_table "candidates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_candidates_on_email", unique: true
  end

  create_table "job_resumes", force: :cascade do |t|
    t.jsonb "analysis_json", default: {}
    t.datetime "created_at", null: false
    t.jsonb "education", default: []
    t.string "email"
    t.bigint "job_id", null: false
    t.integer "match_score"
    t.datetime "matched_at"
    t.string "name"
    t.datetime "parsed_at"
    t.jsonb "parsed_data", default: {}
    t.string "phone"
    t.jsonb "skills", default: []
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["email"], name: "index_job_resumes_on_email"
    t.index ["job_id"], name: "index_job_resumes_on_job_id"
    t.index ["user_id"], name: "index_job_resumes_on_user_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.boolean "ai_generated", default: false
    t.jsonb "ai_metadata", default: {}
    t.text "benefits"
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "currency", default: "INR"
    t.text "description"
    t.string "employment_type"
    t.integer "experience_min"
    t.datetime "expires_at"
    t.string "location"
    t.datetime "published_at"
    t.text "requirements"
    t.text "responsibilities"
    t.integer "salary_max"
    t.integer "salary_min"
    t.jsonb "skills_required", default: []
    t.string "slug", null: false
    t.integer "status", default: 0
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["employment_type"], name: "index_jobs_on_employment_type"
    t.index ["location"], name: "index_jobs_on_location"
    t.index ["skills_required"], name: "index_jobs_on_skills_required", using: :gin
    t.index ["slug"], name: "index_jobs_on_slug", unique: true
    t.index ["status"], name: "index_jobs_on_status"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "applications", "candidates"
  add_foreign_key "applications", "jobs"
  add_foreign_key "job_resumes", "jobs"
  add_foreign_key "job_resumes", "users"
  add_foreign_key "jobs", "users"
end
