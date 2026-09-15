require "test_helper"

class Cpus::NameNormalizerTest < ActiveSupport::TestCase
  # Every string below was taken from the real Open Data snapshot.
  {
    "AMD Ryzen 9 5950X 16-Core Processor" => "AMD Ryzen 9 5950X",
    "AMD Ryzen 9 5950X 16-Core Processor            " => "AMD Ryzen 9 5950X",
    "12th Gen Intel Core i7-12700K" => "Intel Core i7-12700K",
    "11th Gen Intel Core i3-1125G4 @ 2.00GHz" => "Intel Core i3-1125G4",
    "Intel Core i7-10700K CPU @ 3.80GHz" => "Intel Core i7-10700K",
    "Intel(R) Core(TM) i7-2635QM CPU @ 2.00GHz" => "Intel Core i7-2635QM",
    "Intel(R) Xeon(R) CPU           W3680  @ 3.33GHz" => "Intel Xeon W3680",
    "AMD Ryzen 5 PRO 2400G with Radeon Vega Graphics" => "AMD Ryzen 5 PRO 2400G",
    "AMD Ryzen 5 7545U w/ Radeon 740M Graphics" => "AMD Ryzen 5 7545U",
    "AMD A10-5750M APU with Radeon(tm) HD Graphics" => "AMD A10-5750M",
    "INTEL XEON PLATINUM 8568Y+" => "Intel Xeon Platinum 8568Y+",
    "AMD Ryzen Threadripper PRO 5995WX 64-Cores" => "AMD Ryzen Threadripper PRO 5995WX",
    "AMD Athlon(tm) II X4 620 Processor" => "AMD Athlon II X4 620",
    "Intel Celeron CPU  N2840  @ 2.16GHz" => "Intel Celeron N2840",
    "AMD EPYC 4344P 8-Core Processor" => "AMD EPYC 4344P",
    "AMD Ryzen 7 2700X Eight-Core Processor" => "AMD Ryzen 7 2700X",
    "Intel Core Ultra 5 230F" => "Intel Core Ultra 5 230F",
    "Apple M1" => "Apple M1",
    "Intel Xeon w5-3435X" => "Intel Xeon w5-3435X"
  }.each_with_index do |(raw, expected), index|
    test "normalises ##{index} #{raw.strip.truncate(44)}" do
      assert_equal expected, Cpus::NameNormalizer.call(raw).name
    end
  end

  test "adds the vendor when the machine omitted it" do
    assert_equal "AMD Ryzen 7 5800X", Cpus::NameNormalizer.call("Ryzen 7 5800X").name
  end

  test "keeps meaningful capitals in a mixed-case name" do
    # Recasing "5950X" to "5950x" would split one chip across two names.
    assert_equal "AMD Ryzen 9 5950X", Cpus::NameNormalizer.call("AMD Ryzen 9 5950X").name
  end

  # Rejections matter more than matches: a wrong match silently pools two
  # chips' samples into one median.
  {
    "AMD Eng Sample: 100-000001593-40" => "engineering sample",
    "VirtualApple @ 2.50GHz processor" => "virtualised CPU",
    "Genuine Intel(R) CPU 0000 @ 2.20GHz" => "masked model number",
    "Genuine Intel CPU @ 2.20GHz" => "no model number",
    "Intel Xeon CPU @ 2.00GHz" => "no model number",
    "Intel Xeon CPU" => "no model number",
    "" => "no model name"
  }.each do |raw, reason|
    test "rejects #{raw.presence || '(blank)'} as #{reason}" do
      result = Cpus::NameNormalizer.call(raw)
      assert_predicate result, :rejected?
      assert_equal reason, result.rejected_reason
      assert_nil result.name
    end
  end

  test "a name with no model number never becomes a bare brand" do
    # These would otherwise all collapse onto "Intel", pooling unrelated silicon.
    %w[2.20 2.00 2.90].each do |ghz|
      assert_nil Cpus::NameNormalizer.call("Genuine Intel CPU @ #{ghz}GHz").name
    end
  end
end
