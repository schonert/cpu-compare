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

ActiveRecord::Schema[8.0].define(version: 2026_09_14_150000) do
  create_table "benchmark_scores", force: :cascade do |t|
    t.integer "cpu_id", null: false
    t.integer "benchmark_version_id", null: false
    t.integer "workload_id", null: false
    t.string "metric_key", null: false
    t.string "metric_unit", null: false
    t.boolean "higher_is_better", null: false
    t.integer "sample_count", null: false
    t.decimal "median", precision: 16, scale: 4, null: false
    t.decimal "q1", precision: 16, scale: 4
    t.decimal "q3", precision: 16, scale: 4
    t.decimal "iqr", precision: 16, scale: 4
    t.decimal "minimum", precision: 16, scale: 4
    t.decimal "maximum", precision: 16, scale: 4
    t.boolean "suppressed", default: false, null: false
    t.integer "min_samples", null: false
    t.integer "scoring_config_version", null: false
    t.datetime "measured_from"
    t.datetime "measured_to"
    t.datetime "computed_at", null: false
    t.integer "ingest_run_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benchmark_version_id", "workload_id", "suppressed", "median"], name: "index_scores_on_ranking"
    t.index ["benchmark_version_id"], name: "index_benchmark_scores_on_benchmark_version_id"
    t.index ["cpu_id", "benchmark_version_id", "workload_id", "metric_key"], name: "index_scores_on_score_key", unique: true
    t.index ["cpu_id"], name: "index_benchmark_scores_on_cpu_id"
    t.index ["ingest_run_id"], name: "index_benchmark_scores_on_ingest_run_id"
    t.index ["workload_id"], name: "index_benchmark_scores_on_workload_id"
  end

  create_table "benchmark_submissions", force: :cascade do |t|
    t.integer "source_id", null: false
    t.integer "benchmark_version_id", null: false
    t.integer "workload_id", null: false
    t.integer "cpu_id"
    t.string "upstream_id", null: false
    t.integer "entry_index", default: 0, null: false
    t.string "raw_device_name", null: false
    t.decimal "value", precision: 16, scale: 4, null: false
    t.string "metric_key", null: false
    t.decimal "samples_per_minute", precision: 16, scale: 4
    t.decimal "render_time_seconds", precision: 16, scale: 4
    t.decimal "total_render_time_seconds", precision: 16, scale: 4
    t.integer "number_of_samples"
    t.integer "time_limit_seconds"
    t.decimal "device_peak_memory_mb", precision: 14, scale: 2
    t.integer "device_threads"
    t.integer "system_threads"
    t.integer "system_cores"
    t.integer "sockets"
    t.string "operating_system"
    t.string "benchmark_build", null: false
    t.string "launcher_version"
    t.string "script_version"
    t.string "scene_checksum"
    t.string "schema_version"
    t.datetime "measured_at"
    t.boolean "eligible", default: true, null: false
    t.string "exclusion_reason"
    t.integer "first_seen_run_id"
    t.integer "last_seen_run_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benchmark_version_id"], name: "index_benchmark_submissions_on_benchmark_version_id"
    t.index ["cpu_id", "benchmark_version_id", "workload_id", "eligible"], name: "index_submissions_on_score_key"
    t.index ["cpu_id"], name: "index_benchmark_submissions_on_cpu_id"
    t.index ["first_seen_run_id"], name: "index_benchmark_submissions_on_first_seen_run_id"
    t.index ["last_seen_run_id"], name: "index_benchmark_submissions_on_last_seen_run_id"
    t.index ["measured_at"], name: "index_benchmark_submissions_on_measured_at"
    t.index ["raw_device_name"], name: "index_benchmark_submissions_on_raw_device_name"
    t.index ["source_id"], name: "index_benchmark_submissions_on_source_id"
    t.index ["upstream_id", "entry_index"], name: "index_submissions_on_upstream", unique: true
    t.index ["workload_id"], name: "index_benchmark_submissions_on_workload_id"
  end

  create_table "benchmark_suites", force: :cascade do |t|
    t.integer "source_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "protocol", null: false
    t.string "protocol_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_benchmark_suites_on_key", unique: true
    t.index ["source_id"], name: "index_benchmark_suites_on_source_id"
  end

  create_table "benchmark_versions", force: :cascade do |t|
    t.integer "benchmark_suite_id", null: false
    t.string "series", null: false
    t.string "label", null: false
    t.string "metric_key", null: false
    t.string "metric_unit", null: false
    t.boolean "higher_is_better", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benchmark_suite_id", "series"], name: "index_benchmark_versions_on_benchmark_suite_id_and_series", unique: true
    t.index ["benchmark_suite_id"], name: "index_benchmark_versions_on_benchmark_suite_id"
  end

  create_table "cpu_aliases", force: :cascade do |t|
    t.integer "cpu_id"
    t.string "raw_name", null: false
    t.string "normalized_name", null: false
    t.string "match_method", null: false
    t.integer "submission_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpu_id"], name: "index_cpu_aliases_on_cpu_id"
    t.index ["normalized_name"], name: "index_cpu_aliases_on_normalized_name"
    t.index ["raw_name"], name: "index_cpu_aliases_on_raw_name", unique: true
  end

  create_table "cpu_specs", force: :cascade do |t|
    t.integer "cpu_id", null: false
    t.integer "source_id", null: false
    t.string "spec_key", null: false
    t.decimal "value_numeric", precision: 16, scale: 4
    t.string "value_text"
    t.date "value_date"
    t.string "unit"
    t.string "statement_url"
    t.datetime "retrieved_at", null: false
    t.integer "precedence", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "sample_count"
    t.decimal "agreement_percent", precision: 5, scale: 1
    t.index ["cpu_id", "spec_key", "source_id"], name: "index_cpu_specs_on_cpu_attribute_source", unique: true
    t.index ["cpu_id"], name: "index_cpu_specs_on_cpu_id"
    t.index ["source_id"], name: "index_cpu_specs_on_source_id"
  end

  create_table "cpus", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "vendor", null: false
    t.string "wikidata_qid"
    t.integer "cores"
    t.integer "threads"
    t.integer "base_clock_mhz"
    t.integer "boost_clock_mhz"
    t.integer "tdp_watts"
    t.string "socket"
    t.decimal "lithography_nm", precision: 8, scale: 2
    t.decimal "launch_price_usd", precision: 10, scale: 2
    t.date "released_on"
    t.string "microarchitecture"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cpus_on_name"
    t.index ["slug"], name: "index_cpus_on_slug", unique: true
    t.index ["vendor"], name: "index_cpus_on_vendor"
    t.index ["wikidata_qid"], name: "index_cpus_on_wikidata_qid", unique: true
  end

  create_table "ingest_runs", force: :cascade do |t|
    t.string "source_key", null: false
    t.string "kind", null: false
    t.string "status", default: "running", null: false
    t.string "snapshot_label"
    t.string "snapshot_url"
    t.string "snapshot_sha256"
    t.bigint "snapshot_bytes"
    t.datetime "snapshot_taken_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "records_seen", default: 0, null: false
    t.integer "records_skipped", default: 0, null: false
    t.integer "submissions_created", default: 0, null: false
    t.integer "submissions_updated", default: 0, null: false
    t.integer "cpus_created", default: 0, null: false
    t.integer "specs_written", default: 0, null: false
    t.integer "scores_written", default: 0, null: false
    t.text "error_message"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["snapshot_sha256"], name: "index_ingest_runs_on_snapshot_sha256"
    t.index ["source_key", "kind", "started_at"], name: "index_ingest_runs_on_source_kind_time"
  end

  create_table "licensed_benchmark_results", force: :cascade do |t|
    t.integer "source_id", null: false
    t.integer "cpu_id"
    t.string "vendor_reference", null: false
    t.string "cpu_name", null: false
    t.string "metric_key", null: false
    t.string "metric_unit"
    t.decimal "value", precision: 16, scale: 4, null: false
    t.integer "sample_count"
    t.string "license_reference", null: false
    t.date "license_expires_on"
    t.datetime "retrieved_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpu_id"], name: "index_licensed_benchmark_results_on_cpu_id"
    t.index ["source_id", "vendor_reference", "metric_key"], name: "index_licensed_on_source_ref_metric", unique: true
    t.index ["source_id"], name: "index_licensed_benchmark_results_on_source_id"
  end

  create_table "openbenchmarking_results", force: :cascade do |t|
    t.integer "source_id", null: false
    t.integer "cpu_id"
    t.string "test_profile", null: false
    t.string "test_version"
    t.string "metric_key", null: false
    t.string "metric_unit", null: false
    t.boolean "higher_is_better", null: false
    t.string "raw_device_name", null: false
    t.decimal "median", precision: 16, scale: 4, null: false
    t.integer "sample_count", default: 1, null: false
    t.string "upstream_id"
    t.datetime "retrieved_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cpu_id"], name: "index_openbenchmarking_results_on_cpu_id"
    t.index ["source_id"], name: "index_openbenchmarking_results_on_source_id"
    t.index ["test_profile", "test_version", "raw_device_name", "metric_key"], name: "index_obr_on_profile_device_metric", unique: true
  end

  create_table "sources", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "url"
    t.string "terms_url"
    t.string "license", null: false
    t.string "license_url"
    t.boolean "redistributable", default: false, null: false
    t.boolean "licensed", default: false, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_sources_on_key", unique: true
  end

  create_table "workloads", force: :cascade do |t|
    t.integer "benchmark_suite_id", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["benchmark_suite_id", "key"], name: "index_workloads_on_benchmark_suite_id_and_key", unique: true
    t.index ["benchmark_suite_id"], name: "index_workloads_on_benchmark_suite_id"
  end

  add_foreign_key "benchmark_scores", "benchmark_versions"
  add_foreign_key "benchmark_scores", "cpus"
  add_foreign_key "benchmark_scores", "ingest_runs"
  add_foreign_key "benchmark_scores", "workloads"
  add_foreign_key "benchmark_submissions", "benchmark_versions"
  add_foreign_key "benchmark_submissions", "cpus"
  add_foreign_key "benchmark_submissions", "ingest_runs", column: "first_seen_run_id"
  add_foreign_key "benchmark_submissions", "ingest_runs", column: "last_seen_run_id"
  add_foreign_key "benchmark_submissions", "sources"
  add_foreign_key "benchmark_submissions", "workloads"
  add_foreign_key "benchmark_suites", "sources"
  add_foreign_key "benchmark_versions", "benchmark_suites"
  add_foreign_key "cpu_aliases", "cpus"
  add_foreign_key "cpu_specs", "cpus"
  add_foreign_key "cpu_specs", "sources"
  add_foreign_key "licensed_benchmark_results", "cpus"
  add_foreign_key "licensed_benchmark_results", "sources"
  add_foreign_key "openbenchmarking_results", "cpus"
  add_foreign_key "openbenchmarking_results", "sources"
  add_foreign_key "workloads", "benchmark_suites"
end
