module Cpus
  # Writes one sourced fact, then materialises it onto the CPU row.
  #
  # The only supported way to set a spec column. Going around it would put a
  # number on the site with nothing behind it, which is the one thing the
  # presentation contract forbids.
  #
  # Where two sources disagree, both cpu_specs rows survive and the one with
  # the highest precedence wins the materialised column — so the disagreement
  # stays visible instead of being resolved silently at import time.
  class SpecWriter
    # Vendor pages describe their own parts, so they outrank a community edit
    # when both are present.
    PRECEDENCE = {
      Source::BLENDER_REPORTED => 5,
      Source::WIKIDATA => 10,
      Source::AMD_PRODUCT => 20,
      Source::INTEL_ARK => 20
    }.freeze

    NUMERIC = %w[cores threads base_clock_mhz boost_clock_mhz tdp_watts
                 lithography_nm launch_price_usd].freeze
    DATE = %w[released_on].freeze

    def initialize(source)
      @source = source
      @precedence = PRECEDENCE.fetch(source.key, 0)
    end

    def write(cpu, spec_key:, value:, unit: nil, statement_url: nil,
              sample_count: nil, agreement_percent: nil, retrieved_at: Time.current)
      return 0 if value.blank?
      raise ArgumentError, "unknown spec attribute #{spec_key}" unless Cpu::SPEC_ATTRIBUTES.include?(spec_key.to_s)

      spec = CpuSpec.find_or_initialize_by(cpu: cpu, source: @source, spec_key: spec_key.to_s)
      spec.assign_attributes(
        value_numeric: NUMERIC.include?(spec_key.to_s) ? value : nil,
        value_date: DATE.include?(spec_key.to_s) ? value : nil,
        value_text: (NUMERIC + DATE).exclude?(spec_key.to_s) ? value.to_s : nil,
        unit: unit,
        statement_url: statement_url,
        sample_count: sample_count,
        agreement_percent: agreement_percent,
        retrieved_at: retrieved_at,
        precedence: @precedence
      )
      spec.save!
      materialise(cpu, spec_key.to_s)
      1
    end

    private

    # Recomputes the denormalised column from whichever sourced row currently
    # wins, so the two never drift.
    def materialise(cpu, spec_key)
      winner = cpu.cpu_specs.for_key(spec_key).preferred.first
      return if winner.nil?

      value = winner.value_numeric || winner.value_date || winner.value_text
      value = value.to_i if %w[cores threads base_clock_mhz boost_clock_mhz tdp_watts].include?(spec_key)
      cpu.update_column(spec_key, value)
    end
  end
end
