require "test_helper"

class Scoring::ConfigTest < ActiveSupport::TestCase
  def config_for(yaml)
    file = Tempfile.new(["scoring", ".yml"])
    file.write(yaml)
    file.close
    Scoring::Config.new(path: file.path)
  end

  test "the shipped config defines no composite" do
    # The site shows workloads side by side; a blended number would need a
    # deliberate, published change to this file.
    config = Scoring::Config.current
    refute_predicate config, :composites?
    assert_equal "median", config.statistic
    assert_equal 5, config.min_samples
  end

  test "a composite must name a benchmark version" do
    config = config_for(<<~YAML)
      version: 2
      aggregation: { min_samples: 5 }
      composites:
        broken:
          components:
            - { workload: monster, weight: 1.0 }
    YAML

    assert_raises(Scoring::Config::InvalidComposite) { config.composite!("broken") }
  end

  test "a composite whose weights do not sum to one is refused" do
    config = config_for(<<~YAML)
      version: 2
      aggregation: { min_samples: 5 }
      composites:
        broken:
          benchmark_version: "blender:4"
          components:
            - { workload: monster, weight: 0.5 }
            - { workload: junkshop, weight: 0.2 }
    YAML

    error = assert_raises(Scoring::Config::InvalidComposite) { config.composite!("broken") }
    assert_match(/weights sum to/, error.message)
  end

  test "a fully described composite is accepted" do
    config = config_for(<<~YAML)
      version: 2
      aggregation: { min_samples: 5 }
      composites:
        blender_4x:
          label: "Blender 4.x render"
          benchmark_version: "blender:4"
          components:
            - { workload: monster, weight: 0.34 }
            - { workload: junkshop, weight: 0.33 }
            - { workload: classroom, weight: 0.33 }
    YAML

    spec = config.composite!("blender_4x")
    assert_equal "blender:4", spec["benchmark_version"]
    assert_equal 3, spec["components"].size
  end

  test "the config is published verbatim so the rendered rules cannot drift" do
    assert_equal File.read(Rails.root.join("config/scoring.yml")),
                 Scoring::Config.current.source_text
  end
end
