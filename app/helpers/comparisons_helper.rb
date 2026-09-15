module ComparisonsHelper
  # Compare state is a query string, so adding and removing a chip is just a
  # link — no client-side store, and every state is shareable.
  def compare_path_with(slug, selected:, version: nil)
    slugs = (selected + [slug]).uniq.first(Comparison::MAX_CPUS)
    compare_path(cpus: slugs.join(","), version: version.presence)
  end

  def cpus_path_with(slug, selected:, version: nil, workload: nil, **filters)
    slugs = (selected + [slug]).uniq.first(Comparison::MAX_CPUS)
    cpus_path(filters.merge(cpus: slugs.join(","), version: version, workload: workload).compact)
  end

  def compare_path_without(slug, selected:, version: nil)
    compare_path(cpus: (selected - [slug]).join(",").presence, version: version.presence)
  end

  def compare_path_for_version(key, selected:)
    compare_path(cpus: selected.join(",").presence, version: key)
  end

  # Both spellings are written out in full: Tailwind scans source for literal
  # class names, so a colour assembled at runtime would never be generated.
  VENDOR_COLOURS = {
    "amd" => { bg: "bg-vendor-amd", text: "text-vendor-amd" },
    "intel" => { bg: "bg-vendor-intel", text: "text-vendor-intel" },
    "apple" => { bg: "bg-vendor-apple", text: "text-vendor-apple" },
    "qualcomm" => { bg: "bg-vendor-qualcomm", text: "text-vendor-qualcomm" },
    "arm" => { bg: "bg-vendor-arm", text: "text-vendor-arm" }
  }.freeze

  FALLBACK_COLOUR = { bg: "bg-vendor-other", text: "text-vendor-other" }.freeze

  def vendor_accent(vendor) = VENDOR_COLOURS.fetch(vendor, FALLBACK_COLOUR)[:bg]
  def vendor_ink(vendor) = VENDOR_COLOURS.fetch(vendor, FALLBACK_COLOUR)[:text]

  # Formatted here rather than in the model so the same figure can be rendered
  # differently in a chart and in a table.
  def format_metric(value, format:, unit: nil)
    return tag.span("—", class: "text-ink-faint") if value.nil? || value == "" || value == 0

    formatted =
      case format
      when :integer then number_with_delimiter(value.to_i)
      when :decimal then number_with_precision(value, precision: value.to_f == value.to_f.round ? 0 : 1,
                                                      delimiter: ",")
      when :money   then number_to_currency(value, precision: 0)
      when :clock   then "#{number_with_precision(value.to_f / 1000, precision: 2)} GHz"
      when :date    then value.respond_to?(:strftime) ? value.strftime("%b %Y") : value.to_s
      else value.to_s
      end

    safe_join([formatted, (tag.span(unit, class: "text-ink-muted font-normal text-xs ms-1") if unit)].compact)
  end

  # A measurement's value with its unit. Every figure on the site goes through
  # here or through FigureComponent, so no number is ever printed bare.
  def score_value(score)
    precision = score.median.to_f >= 100 ? 0 : 1
    "#{number_with_precision(score.median, precision: precision, delimiter: ',')} #{score.metric_unit}"
  end
end
