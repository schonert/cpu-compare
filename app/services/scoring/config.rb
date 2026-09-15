module Scoring
  # Reads config/scoring.yml. That file — not this class — is the statement of
  # how figures are produced, and it is rendered publicly at /methodology, so
  # the rules cannot drift away from what the site claims they are.
  class Config
    PATH = Rails.root.join("config/scoring.yml")

    class InvalidComposite < StandardError; end

    def self.current = @current ||= new
    def self.reload! = @current = new

    def initialize(path: PATH)
      @path = path
      @data = YAML.safe_load_file(path, permitted_classes: [Date]).freeze
    end

    attr_reader :path

    def version = @data.fetch("version")
    def effective_from = @data["effective_from"]
    def raw = @data
    def source_text = File.read(@path)

    def statistic = aggregation.fetch("statistic", "median")
    def quantile_method = aggregation.fetch("quantile_method", "linear_interpolation")
    def min_samples = aggregation.fetch("min_samples", 5).to_i

    def exclude_thread_restricted? = eligibility.fetch("exclude_thread_restricted", true)
    def single_socket_only? = eligibility.fetch("single_socket_only", true)
    def exclude_crashed? = eligibility.fetch("exclude_crashed", true)

    def composites = @data["composites"] || {}
    def composites? = composites.any?

    # A composite may only exist if it is fully described here: a label, a
    # single benchmark version, and weights that sum to 1. Anything else raises
    # rather than quietly producing a number nobody can account for.
    def composite!(key)
      spec = composites.fetch(key) { raise InvalidComposite, "no composite named #{key.inspect}" }
      components = spec["components"] || []
      raise InvalidComposite, "#{key} has no components" if components.empty?
      raise InvalidComposite, "#{key} names no benchmark_version" if spec["benchmark_version"].blank?

      total = components.sum { |c| c.fetch("weight", 0).to_f }
      unless (total - 1.0).abs < 1e-6
        raise InvalidComposite, "#{key} weights sum to #{total}, expected 1.0"
      end

      spec
    end

    private

    def aggregation = @data.fetch("aggregation", {})
    def eligibility = @data.fetch("eligibility", {})
  end
end
