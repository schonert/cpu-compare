require "test_helper"

class Cpus::ReportedSpecsTest < ActiveSupport::TestCase
  test "reads the core and thread count the machines reported" do
    cpu = create_cpu(name: "AMD Ryzen 9 5950X")
    5.times { create_submission(cpu: cpu, value: 100, system_cores: 16, system_threads: 32) }

    Cpus::ReportedSpecs.call

    assert_equal 16, cpu.reload.cores
    assert_equal 32, cpu.threads
  end

  test "takes the mode, so a handful of under-reporting VMs do not move it" do
    cpu = create_cpu(name: "AMD Ryzen 9 5900X")
    # The real shape of this data: overwhelming agreement plus a few VMs.
    20.times { create_submission(cpu: cpu, value: 100, system_cores: 12, system_threads: 24) }
    2.times { create_submission(cpu: cpu, value: 40, system_cores: 6, system_threads: 12) }

    Cpus::ReportedSpecs.call

    assert_equal 12, cpu.reload.cores
    assert_equal 24, cpu.threads
  end

  test "stores how many runs agreed, so a shaky figure reads as one" do
    cpu = create_cpu(name: "AMD Ryzen 7 5800X")
    18.times { create_submission(cpu: cpu, value: 100, system_cores: 8, system_threads: 16) }
    2.times { create_submission(cpu: cpu, value: 100, system_cores: 4, system_threads: 8) }

    Cpus::ReportedSpecs.call
    spec = cpu.cpu_specs.for_key("cores").sole

    assert_equal 20, spec.sample_count
    assert_in_delta 90.0, spec.agreement_percent.to_f, 0.1
  end

  test "publishes nothing when the machines do not agree" do
    cpu = create_cpu(name: "Intel Xeon E5-2690")
    4.times { create_submission(cpu: cpu, value: 100, system_cores: 8, system_threads: 16) }
    4.times { create_submission(cpu: cpu, value: 100, system_cores: 16, system_threads: 32) }

    Cpus::ReportedSpecs.call

    assert_nil cpu.reload.cores, "a 50/50 split is not a specification"
    assert_empty cpu.cpu_specs
  end

  test "publishes nothing from too few reports for a mode to mean anything" do
    cpu = create_cpu(name: "AMD EPYC 9755")
    2.times { create_submission(cpu: cpu, value: 100, system_cores: 128, system_threads: 256) }

    Cpus::ReportedSpecs.call
    assert_nil cpu.reload.cores
  end

  test "ignores submissions that were excluded from scoring" do
    cpu = create_cpu(name: "AMD Ryzen 5 5600X")
    5.times { create_submission(cpu: cpu, value: 100, system_cores: 6, system_threads: 12) }
    # A dual-socket machine reports the whole system, not the processor.
    9.times do
      create_submission(cpu: cpu, value: 100, system_cores: 12, system_threads: 24,
                        eligible: false, exclusion_reason: BenchmarkSubmission::MULTI_SOCKET)
    end

    Cpus::ReportedSpecs.call
    assert_equal 6, cpu.reload.cores
  end

  test "a vendor or Wikidata figure outranks the measured one" do
    cpu = create_cpu(name: "Intel Core i7-6700")
    5.times { create_submission(cpu: cpu, value: 100, system_cores: 2, system_threads: 4) }
    Cpus::ReportedSpecs.call
    assert_equal 2, cpu.reload.cores

    Cpus::SpecWriter.new(Source[Source::WIKIDATA])
                    .write(cpu, spec_key: "cores", value: 4,
                                statement_url: "https://www.wikidata.org/wiki/Q1")

    assert_equal 4, cpu.reload.cores, "a stated specification must win"
    # Both rows survive, so the disagreement stays visible.
    assert_equal 2, cpu.cpu_specs.for_key("cores").count
  end

  test "re-running overwrites rather than duplicating" do
    cpu = create_cpu(name: "Apple M1")
    5.times { create_submission(cpu: cpu, value: 100, system_cores: 8, system_threads: 8) }

    Cpus::ReportedSpecs.call
    Cpus::ReportedSpecs.call

    assert_equal 1, cpu.cpu_specs.for_key("cores").count
    assert_equal 8, cpu.reload.cores
  end

  test "the derived source is CC0 and redistributable" do
    source = Source[Source::BLENDER_REPORTED]
    assert_predicate source, :redistributable?
    refute_predicate source, :licensed?
    assert_equal "CC0-1.0", source.license
  end

  test "the spec table cites the runs a measured figure came from" do
    cpu = create_cpu(name: "AMD Ryzen 9 5950X")
    20.times { create_submission(cpu: cpu, value: 100, system_cores: 16, system_threads: 32) }
    Cpus::ReportedSpecs.call
    Scoring::Aggregator.call

    row = Comparison::SpecRow.new({ attribute: "cores", label: "Cores", format: :integer }, [cpu])
    component = SpecTableComponent.new(comparison: Comparison.new(cpus: [cpu]))

    assert_equal "Reported by machines", component.source_label(row, cpu)
    assert_equal "20 runs agree", component.sample_label(row, cpu)
  end
end
