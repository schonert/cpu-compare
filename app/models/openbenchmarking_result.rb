# OpenBenchmarking.org results, if a CSV/XML export is ever ingested.
#
# A separate table on purpose: a Phoronix Test Suite result is a different
# protocol with its own metric vocabulary, and there is no schema path that
# would let it merge into a Blender score. Nothing in Scoring::Aggregator reads
# this table.
class OpenbenchmarkingResult < ApplicationRecord
  belongs_to :source
  belongs_to :cpu, optional: true

  validates :test_profile, :metric_key, :metric_unit, :raw_device_name, presence: true
  validates :median, :retrieved_at, presence: true
end
