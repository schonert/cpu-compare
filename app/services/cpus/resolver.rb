module Cpus
  # Resolves raw device strings to CPU records, and remembers every decision.
  #
  # Kept as a long-lived object across one ingest: the alias table is loaded
  # once and consulted in memory, so resolving 650,000 submissions costs one
  # query rather than one query each.
  #
  # Manual aliases are never overwritten. Setting cpu_id by hand and marking the
  # row "manual" is the supported way to fix a mismatch, and re-running ingest
  # must not undo it.
  class Resolver
    Resolution = Struct.new(:cpu_id, :rejected_reason, keyword_init: true) do
      def matched? = cpu_id.present?
    end

    def initialize
      @aliases = CpuAlias.pluck(:raw_name, :cpu_id, :match_method)
                         .to_h { |raw, cpu_id, method| [raw, [cpu_id, method]] }
      @cpus_by_name = Cpu.pluck(:name, :id).to_h
      @seen = Hash.new(0)
      @new_aliases = {}
      @cpus_created = 0
    end

    attr_reader :cpus_created

    def call(raw_name)
      @seen[raw_name] += 1

      cached = @aliases[raw_name]
      return resolution_for(cached) if cached

      result = NameNormalizer.call(raw_name)

      if result.rejected?
        record_alias(raw_name, raw_name, nil, CpuAlias::UNMATCHED)
        return Resolution.new(rejected_reason: result.rejected_reason)
      end

      cpu_id = find_or_create_cpu(result)
      method = @cpus_by_name.key?(result.name) ? CpuAlias::RULE : CpuAlias::EXACT
      record_alias(raw_name, result.name, cpu_id, raw_name == result.name ? CpuAlias::EXACT : method)
      Resolution.new(cpu_id: cpu_id)
    end

    # Writes the aliases discovered during this run and refreshes the counts,
    # so "how much of the feed do we actually resolve?" stays answerable.
    def flush!
      @new_aliases.each_slice(500) do |batch|
        CpuAlias.upsert_all(
          batch.map { |_, row| row },
          unique_by: :index_cpu_aliases_on_raw_name,
          record_timestamps: true
        )
      end
      @new_aliases.clear

      @seen.each_slice(500) do |batch|
        CpuAlias.where(raw_name: batch.map(&:first))
                .find_each { |a| a.update_column(:submission_count, @seen[a.raw_name]) }
      end
    end

    private

    def resolution_for((cpu_id, method))
      return Resolution.new(cpu_id: cpu_id) if cpu_id
      # A previously unmatched string stays unmatched unless a human intervened.
      Resolution.new(rejected_reason: method == CpuAlias::MANUAL ? "excluded by hand" : "unidentifiable name")
    end

    def find_or_create_cpu(result)
      existing = @cpus_by_name[result.name]
      return existing if existing

      cpu = Cpu.create!(name: result.name, vendor: result.vendor, slug: unique_slug(result.name))
      @cpus_created += 1
      @cpus_by_name[result.name] = cpu.id
    end

    def unique_slug(name)
      base = name.parameterize
      slug = base
      suffix = 2
      slug = "#{base}-#{suffix += 1}" while Cpu.exists?(slug: slug)
      slug
    end

    def record_alias(raw_name, normalized, cpu_id, method)
      @aliases[raw_name] = [cpu_id, method]
      @new_aliases[raw_name] = {
        raw_name: raw_name, normalized_name: normalized,
        cpu_id: cpu_id, match_method: method, submission_count: 0
      }
    end
  end
end
