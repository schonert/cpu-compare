# Footer credit and licence. The data is somebody else's work released into the
# public domain, so it says so on every page, alongside the snapshot the
# figures came from.
class ProvenanceComponent < ApplicationComponent
  def ingested_at = Catalogue.last_ingested_at

  def ingested_label
    return "not yet ingested" if ingested_at.nil?

    "#{ingested_at.utc.strftime('%-d %b %Y')} (#{time_ago_in_words(ingested_at)} ago)"
  end

  def snapshot_label = Catalogue.snapshot_label
end
