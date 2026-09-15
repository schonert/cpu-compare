# Previous / next paging. Deliberately minimal: the browse table is a lookup
# tool, and the filters do the narrowing.
#
# Takes a path builder rather than a query hash so the same component serves
# the browse table and the measurements list, which live on different routes.
class PaginationComponent < ApplicationComponent
  def initialize(page:, per_page:, total:, path:)
    @page = page
    @per_page = per_page
    @total = total
    @path = path
  end

  attr_reader :page, :per_page, :total

  def render? = total > per_page

  def last_page = (total.to_f / per_page).ceil
  def first? = page <= 1
  def last? = page >= last_page

  def path_for(target) = @path.call(target)

  def range_label
    from = ((page - 1) * per_page) + 1
    to = [page * per_page, total].min
    "#{number_with_delimiter(from)}–#{number_with_delimiter(to)} of #{number_with_delimiter(total)}"
  end

  def link_classes
    "rounded-md bg-panel px-4 py-2 text-[13px] font-medium shadow-border transition hover:bg-ink hover:text-panel"
  end

  def disabled_classes = "rounded-md px-4 py-2 text-[13px] font-medium text-ink-faint"
end
