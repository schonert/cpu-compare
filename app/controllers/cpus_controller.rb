class CpusController < ApplicationController
  PER_PAGE = 50

  # Browsing ranks by one workload at a time. There is no "overall" option,
  # because there is no blended figure to sort by — that is the point.
  def index
    @version = requested_version
    @workload = requested_workload
    @filters = filter_params
    @selected = Comparison.slugs_from(params[:cpus])

    scope = filtered_scores
    @total = scope.count
    @page = [params[:page].to_i, 1].max
    @scores = scope.ranked.includes(:cpu, :workload, :benchmark_version)
                   .offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  # Type-ahead results, rendered into a Turbo Frame on the compare screen.
  def search
    @query = params[:q].to_s.strip
    @selected = Comparison.slugs_from(params[:cpus])
    @results = @query.length < 2 ? Cpu.none : Cpu.scored.named_like(@query).order(:name).limit(12)

    render partial: "cpus/search_results",
           locals: { results: @results, query: @query, selected: @selected,
                     version: params[:version] }
  end

  private

  def requested_version
    Catalogue.versions.find { |v| v.to_param == params[:version] } || Catalogue.default_version
  end

  def requested_workload
    return if @version.nil?

    workloads = @version.scored_workloads
    workloads.find { |w| w.key == params[:workload] } || workloads.first
  end

  def filter_params
    params.permit(:q, :vendor).to_h.symbolize_keys.compact_blank
  end

  def filtered_scores
    return BenchmarkScore.none if @version.nil? || @workload.nil?

    scope = BenchmarkScore.displayable.for_version(@version).for_workload(@workload)
    scope = scope.joins(:cpu).merge(Cpu.named_like(@filters[:q])) if @filters[:q].present?
    scope = scope.joins(:cpu).merge(Cpu.by_vendor(@filters[:vendor])) if @filters[:vendor].present?
    scope
  end
end
