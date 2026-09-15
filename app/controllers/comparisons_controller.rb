class ComparisonsController < ApplicationController
  # The comparison lives entirely in the query string, so any view can be
  # bookmarked or shared and still mean the same thing.
  def show
    @version = requested_version
    @comparison = Comparison.new(cpus: selected_cpus, version: @version)
    @selected_slugs = @comparison.slugs
    @suggestions = suggested_cpus if @comparison.empty?
  end

  private

  def requested_version
    return Catalogue.default_version if params[:version].blank?

    Catalogue.versions.find { |v| v.to_param == params[:version] } || Catalogue.default_version
  end

  def selected_cpus
    slugs = Comparison.slugs_from(params[:cpus])
    return [] if slugs.empty?

    found = Cpu.where(slug: slugs).index_by(&:slug)
    slugs.filter_map { |slug| found[slug] }
  end

  # A starting point when nothing is selected: the fastest chips on the
  # busiest workload of the current series.
  def suggested_cpus
    return [] if @version.nil?

    workload = @version.scored_workloads.first
    return [] if workload.nil?

    ids = BenchmarkScore.displayable.for_version(@version).for_workload(workload)
                        .ranked.limit(6).pluck(:cpu_id)
    Cpu.where(id: ids).index_by(&:id).values_at(*ids).compact
  end
end
