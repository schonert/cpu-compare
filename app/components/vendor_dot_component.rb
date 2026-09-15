# The small coloured dot that identifies a CPU's vendor at a glance.
#
# Bars are monochrome so the accent can mark the leader, which leaves the dot
# as the place vendor identity lives.
class VendorDotComponent < ApplicationComponent
  def initialize(vendor:, size: :sm)
    @vendor = vendor
    @size = size
  end

  def call
    tag.span(nil, class: ["inline-block shrink-0 rounded-full", dimension, vendor_accent(@vendor)],
                  aria: { hidden: true })
  end

  private

  def dimension = @size == :lg ? "size-2.5" : "size-[7px]"
end
