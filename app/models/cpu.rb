# A processor.
#
# A CPU exists here because something measured it — the catalogue is built from
# the benchmark data, not from a spec sheet. Specifications are optional
# enrichment layered on top: Wikidata carries detailed specs for only a few
# hundred parts, so most of the catalogue has scores and an empty spec sheet,
# and that is the normal case rather than a defect.
#
# The spec columns on this table are a materialised view of `cpu_specs`, which
# holds the source, the deep link to the exact statement and the date it was
# read. Never write them directly — go through Cpus::SpecWriter so the
# provenance row is written alongside.
class Cpu < ApplicationRecord
  has_many :benchmark_submissions, dependent: :destroy
  has_many :benchmark_scores, dependent: :destroy
  has_many :cpu_aliases, dependent: :nullify
  has_many :cpu_specs, dependent: :destroy

  # Attributes that may be materialised onto this table from a cpu_specs row.
  SPEC_ATTRIBUTES = %w[
    cores threads base_clock_mhz boost_clock_mhz tdp_watts
    socket lithography_nm launch_price_usd released_on microarchitecture
  ].freeze

  validates :slug, :name, :vendor, presence: true
  validates :slug, uniqueness: true

  # Qualified: this scope gets merged onto relations that also join `workloads`,
  # which has its own `name` column, and an unqualified one is ambiguous there.
  scope :named_like, lambda { |q|
    where("cpus.name LIKE ?", "%#{sanitize_sql_like(q.to_s.strip)}%") if q.present?
  }
  scope :by_vendor, ->(v) { where(vendor: v) if v.present? }
  # Only chips with at least one figure we are willing to display.
  scope :scored, -> { where(id: BenchmarkScore.displayable.select(:cpu_id)) }

  def to_param = slug

  def specced? = cpu_specs.any?

  # True when we hold no specification at all — common, and worth saying out
  # loud in the UI rather than rendering a table of dashes.
  def spec_sheet_empty? = SPEC_ATTRIBUTES.none? { |a| self[a].present? }

  def base_clock_ghz  = base_clock_mhz && (base_clock_mhz / 1000.0).round(2)
  def boost_clock_ghz = boost_clock_mhz && (boost_clock_mhz / 1000.0).round(2)
  def released_label  = released_on&.strftime("%b %Y")

  VENDOR_PATTERNS = {
    "amd" => /\b(AMD|Ryzen|Threadripper|EPYC|Athlon|Opteron|Phenom|FX-)\b/i,
    "intel" => /\b(Intel|Xeon|Pentium|Celeron|Core\s+i[3579]|Core\s+Ultra)\b/i,
    "apple" => /\bApple\b|\bM[1-9](\s|$)/i,
    "qualcomm" => /\b(Qualcomm|Snapdragon|Oryon)\b/i,
    "arm" => /\b(ARM|Cortex-|Neoverse|Ampere)\b/i,
    "mediatek" => /\bMediaTek\b/i,
    "samsung" => /\b(Samsung|Exynos)\b/i
  }.freeze

  VENDOR_LABELS = {
    "amd" => "AMD", "intel" => "Intel", "apple" => "Apple", "qualcomm" => "Qualcomm",
    "arm" => "Arm", "mediatek" => "MediaTek", "samsung" => "Samsung", "other" => "Other"
  }.freeze

  def vendor_label = self.class.vendor_label_for(vendor)

  def self.vendor_label_for(vendor) = VENDOR_LABELS.fetch(vendor, vendor.to_s.titleize)

  def self.vendor_for(name)
    VENDOR_PATTERNS.find { |_, pattern| name.to_s.match?(pattern) }&.first || "other"
  end
end
