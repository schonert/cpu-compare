# Catalogue-wide aggregates used to populate filters and footers.
#
# Cheap, slow-moving data — the numbers only move when an ingest runs, so the
# cache key is the last successful run.
module Catalogue
  CACHE_TTL = 12.hours

  module_function

  def vendors
    cached("vendors") do
      Cpu.scored.group(:vendor).count.sort_by { |vendor, count| [-count, vendor] }.map(&:first)
    end
  end

  def size = cached("size") { Cpu.scored.count }
  def submission_count = cached("submissions") { BenchmarkSubmission.eligible.count }

  def default_version
    cached("default_version") do
      BenchmarkScore.displayable
                    .group(:benchmark_version_id)
                    .count
                    .max_by { |_, count| count }
                    &.first
    end.then { |id| id && BenchmarkVersion.find_by(id: id) }
  end

  def versions
    ids = cached("version_ids") { BenchmarkScore.displayable.distinct.pluck(:benchmark_version_id) }
    BenchmarkVersion.where(id: ids).ordered.to_a
  end

  def last_ingested_at = IngestRun.latest_success(kind: IngestRun::BLENDER_SNAPSHOT)&.finished_at
  def last_scored_at = IngestRun.latest_success(kind: IngestRun::SCORING)&.finished_at

  def snapshot_label
    IngestRun.latest_success(kind: IngestRun::BLENDER_SNAPSHOT)&.snapshot_label
  end

  def cached(name, &block)
    Rails.cache.fetch("catalogue/#{name}/#{cache_key}", expires_in: CACHE_TTL, &block)
  end

  def cache_key = last_scored_at&.to_i || "empty"
end
