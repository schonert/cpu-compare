# The small coloured dot that identifies a CPU's vendor at a glance.
#
# Bars are monochrome for every row, so the dot is the place vendor identity
# lives — status color at dot scale, as DESIGN.md requires.
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
