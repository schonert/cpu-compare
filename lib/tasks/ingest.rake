namespace :ingest do
  desc "Download the latest Blender Open Data snapshot (skips if already present; FORCE=1 to refresh)"
  task snapshot: :environment do
    snapshot = BlenderOpenData::Snapshot.new
    snapshot.fetch!(force: ENV["FORCE"].present?)
    puts "#{snapshot.label}  #{(snapshot.bytes / 1024.0 / 1024).round(1)} MB"
    puts "sha256 #{snapshot.sha256}"
    puts "licence #{snapshot.cc0? ? 'CC0 1.0 — verified from LICENSE.txt in the archive' : 'NOT CC0 — ingest will refuse'}"
  end

  desc "Ingest the Blender Open Data snapshot into benchmark_submissions (idempotent)"
  task blender: :environment do
    snapshot = BlenderOpenData::Snapshot.new
    snapshot.fetch!
    run = BlenderOpenData::Importer.call(snapshot: snapshot)
    puts "#{run.status}: #{run.records_seen} measurements seen, " \
         "#{run.submissions_created} written, #{run.records_skipped} skipped, " \
         "#{run.cpus_created} new processors, in #{run.duration.round(1)}s"
    puts run.details.map { |k, v| "  #{k.tr('_', ' ')}: #{v}" }
  end

  desc "Read core and thread counts back out of the stored submissions"
  task reported_specs: :environment do
    run = Cpus::ReportedSpecs.call
    puts "#{run.status}: #{run.specs_written} specifications in #{run.duration.round(1)}s"
    puts run.details.map { |k, v| "  #{k.tr('_', ' ')}: #{v}" }
  end

  desc "Recompute every score from the stored submissions"
  task score: :environment do
    run = Scoring::Aggregator.call
    puts "#{run.status}: #{run.scores_written} scores in #{run.duration.round(1)}s"
    puts run.details.map { |k, v| "  #{k.tr('_', ' ')}: #{v}" }
  end

  desc "Attach Wikidata specifications to processors already in the catalogue"
  task wikidata: :environment do
    run = Wikidata::SpecImporter.call
    puts "#{run.status}: #{run.specs_written} specifications in #{run.duration.round(1)}s"
    puts run.details.map { |k, v| "  #{k.tr('_', ' ')}: #{v}" }
  end

  desc "Full refresh: snapshot, ingest, specs, scores"
  task all: :environment do
    %w[ingest:snapshot ingest:blender ingest:reported_specs ingest:wikidata ingest:score]
      .each do |name|
      puts "\n== #{name} =="
      Rake::Task[name].invoke
    end
  end

  desc "Report what is and is not resolved in the catalogue"
  task status: :environment do
    puts "processors          #{Cpu.count} (#{Cpu.scored.count} with a displayable score)"
    puts "submissions         #{BenchmarkSubmission.count} (#{BenchmarkSubmission.eligible.count} eligible)"
    BenchmarkSubmission.where.not(exclusion_reason: nil).group(:exclusion_reason).count
                       .sort_by { |_, v| -v }.each { |r, c| puts "  excluded #{r.tr('_', ' ')}: #{c}" }
    puts "device name aliases #{CpuAlias.count} (#{CpuAlias.unmatched.count} unresolved)"
    puts "scores              #{BenchmarkScore.count} (#{BenchmarkScore.displayable.count} displayable, " \
         "#{BenchmarkScore.where(suppressed: true).count} suppressed below N=#{Scoring::Config.current.min_samples})"
    puts "specifications      #{CpuSpec.count} facts on #{Cpu.joins(:cpu_specs).distinct.count} processors"
    puts "\nlast runs:"
    IngestRun.recent.limit(5).each do |run|
      puts format("  %-18s %-10s %s", run.kind, run.status, run.started_at&.strftime("%Y-%m-%d %H:%M"))
    end
  end
end
