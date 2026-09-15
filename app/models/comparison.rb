# The compare screen's domain object: a handful of CPUs read against one
# benchmark version.
#
# Deliberately has no headline number. The presentation contract asks for
# per-workload results side by side rather than one collapsed rank, and
# config/scoring.yml defines no composite, so there is nothing here that blends
# workloads together. Each workload is its own chart and each chart's figures
# carry their own sample count, spread and date.
class Comparison
  MAX_CPUS = 4

  attr_reader :cpus, :version

  def initialize(cpus: [], version: nil)
    @cpus = Array(cpus).first(MAX_CPUS)
    @version = version || Catalogue.default_version
  end

  # Accepts "?cpus=a,b,c" in any shape and returns clean, capped slugs.
  def self.slugs_from(value)
    value.to_s.split(",").map(&:strip).reject(&:empty?).uniq.first(MAX_CPUS)
  end

  def empty? = cpus.empty?
  def full? = cpus.size >= MAX_CPUS
  def free_slots = MAX_CPUS - cpus.size
  def slugs = cpus.map(&:slug)
  def versions = Catalogue.versions

  # One chart per workload, in a stable order, containing only workloads where
  # at least one selected CPU has a displayable figure.
  def workload_charts
    @workload_charts ||= begin
      return [] if version.nil? || cpus.empty?

      # Unpublished (too few samples) scores still draw as faded bars, so load
      # them alongside the published figures. A chart is only shown when at
      # least one published bar is present.
      scores = BenchmarkScore.where(cpu_id: cpus.map(&:id), benchmark_version: version)
                             .index_by { |s| [s.cpu_id, s.workload_id] }

      version.scored_workloads.filter_map do |workload|
        chart = WorkloadChart.new(workload: workload, version: version, cpus: cpus, scores: scores)
        chart if chart.render?
      end
    end
  end

  # Reference facts. Sourced from cpu_specs, and a row is dropped entirely
  # rather than rendered as a line of dashes when nothing is known.
  def spec_rows
    @spec_rows ||= SPECS.map { |spec| SpecRow.new(spec, cpus) }.select(&:any?)
  end

  def spec_sheet_empty? = spec_rows.empty?

  SPECS = [
    { attribute: "cores", label: "Cores", format: :integer },
    { attribute: "threads", label: "Threads", format: :integer },
    { attribute: "base_clock_mhz", label: "Base clock", format: :clock },
    { attribute: "boost_clock_mhz", label: "Boost clock", format: :clock },
    { attribute: "tdp_watts", label: "TDP", format: :integer, unit: "W" },
    { attribute: "socket", label: "Socket", format: :text },
    { attribute: "lithography_nm", label: "Lithography", format: :decimal, unit: "nm" },
    { attribute: "launch_price_usd", label: "Launch price", format: :money },
    { attribute: "released_on", label: "Released", format: :date },
    { attribute: "microarchitecture", label: "Microarchitecture", format: :text }
  ].freeze

  # One specification across the compared CPUs, carrying the source of each
  # value so the cell can cite it.
  class SpecRow
    attr_reader :spec_key, :label, :format, :unit

    def initialize(spec, cpus)
      @spec_key = spec[:attribute]
      @label = spec[:label]
      @format = spec[:format]
      @unit = spec[:unit]
      @cpus = cpus
      @specs = CpuSpec.where(cpu_id: cpus.map(&:id), spec_key: @spec_key)
                      .preferred.includes(:source).group_by(&:cpu_id)
    end

    def any? = @cpus.any? { |cpu| value_for(cpu).present? }
    def value_for(cpu) = cpu.public_send(@spec_key)
    def spec_for(cpu) = @specs[cpu.id]&.first
    def source_for(cpu) = spec_for(cpu)&.source
    def cells = @cpus.map { |cpu| [cpu, value_for(cpu), spec_for(cpu)] }
  end

  # One workload drawn as a bar chart across the compared CPUs.
  #
  # Bars are scaled against the best figure among the compared chips, not
  # against the catalogue, so the comparison is between what is on screen.
  class WorkloadChart
    Bar = Struct.new(:cpu, :score, :percent, :best, keyword_init: true) do
      def missing? = score.nil?
      def unpublished? = score.present? && score.suppressed?
      def published? = score.present? && !score.suppressed?
    end

    attr_reader :workload, :version, :bars

    def initialize(workload:, version:, cpus:, scores:)
      @workload = workload
      @version = version
      present = cpus.filter_map { |cpu| scores[[cpu.id, workload.id]] }
      published = present.reject(&:suppressed?)
      @best = best_of(published)
      # Computed across every bar before any is scaled, so all bars on one
      # chart share a single scale — including unpublished figures, so a
      # faded bar still reads against the same axis.
      @scale_max = present.map { |score| score.median.to_f }.max

      @bars = cpus.map do |cpu|
        score = scores[[cpu.id, workload.id]]
        Bar.new(cpu: cpu, score: score, percent: percent_for(score),
                best: score.present? && !score.suppressed? && @best.present? && score.id == @best.id)
      end
    end

    def render? = bars.any?(&:published?)
    def metric_unit = version.metric_unit
    def higher_is_better? = version.higher_is_better
    def scale_max = @scale_max

    def direction_note
      higher_is_better? ? "Higher is better" : "Lower is better — the bar shows time taken"
    end

    private

    def best_of(scores)
      return if scores.empty?

      version.higher_is_better ? scores.max_by(&:median) : scores.min_by(&:median)
    end

    # Bar length is always proportional to the raw figure, including on a
    # lower-is-better metric, so the longest bar is the slowest chip rather
    # than a number dressed up as a score.
    def percent_for(score)
      return 0 if score.nil? || @scale_max.to_f <= 0

      (score.median.to_f / @scale_max * 100).clamp(0, 100).round(2)
    end
  end
end
