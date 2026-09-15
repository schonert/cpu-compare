# The browse table: one row per processor, ranked on a single workload.
#
# There is no "overall" column to sort by. The ranking is always "fastest on
# this scene, in this benchmark series", which is a claim the data can actually
# support — and each row's figure links to the runs behind it.
class CpuTableComponent < ApplicationComponent
  def initialize(scores:, version:, workload:, filters:, selected:, offset: 0)
    @scores = scores
    @version = version
    @workload = workload
    @filters = filters
    @selected = selected
    @offset = offset
  end

  attr_reader :scores, :version, :workload, :filters, :selected, :offset

  def rank_for(index) = offset + index + 1

  def workload_path(key)
    cpus_path(filters.merge(version: version&.to_param, workload: key,
                            cpus: selected.join(",").presence).compact)
  end

  def workloads = version&.scored_workloads || []

  def current_workload?(candidate) = workload.present? && candidate.id == workload.id

  def tab_classes(candidate)
    ["rounded-md px-3 py-1 text-[12px] font-medium transition-colors",
     current_workload?(candidate) ? "bg-ink text-panel" : "text-ink-muted hover:bg-hover hover:text-ink"]
  end

  def selected?(cpu) = selected.include?(cpu.slug)
  def full? = selected.size >= Comparison::MAX_CPUS

  def add_path(cpu)
    cpus_path_with(cpu.slug, selected: selected, version: version&.to_param,
                   workload: workload&.key, **filters)
  end
end
