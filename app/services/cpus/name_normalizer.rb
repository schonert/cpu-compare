module Cpus
  # Turns the raw device string an OS reports into a canonical processor name.
  #
  # Blender Open Data records whatever the machine called itself, so the same
  # chip arrives in a dozen spellings:
  #
  #   "AMD Ryzen 9 5950X 16-Core Processor"
  #   "12th Gen Intel Core i7-12700K"
  #   "Intel(R) Xeon(R) CPU           W3680  @ 3.33GHz"
  #   "AMD Ryzen 5 PRO 2400G with Radeon Vega Graphics"
  #
  # All of that is decoration around a model number. The rules below strip it.
  # Anything that cannot be resolved to a real part — engineering samples,
  # virtualised CPUs, masked model numbers — is rejected with a reason rather
  # than guessed at, because a wrong match silently merges two chips' samples.
  class NameNormalizer
    Result = Struct.new(:name, :vendor, :rejected_reason, keyword_init: true) do
      def matched? = name.present?
      def rejected? = rejected_reason.present?
    end

    # Strings that identify no specific part. Matching these would pool
    # unrelated hardware under one name.
    REJECT = [
      [/\beng(ineering)?\s+sample\b/i, "engineering sample"],
      [/\bES\s*:\s*\w+/i, "engineering sample"],
      [/\bvirtual(apple|box|cpu)?\b/i, "virtualised CPU"],
      [/\bQEMU\b|\bKVM\b|\bpc-i440fx\b/i, "virtualised CPU"],
      [/\bCPU\s+0{3,}\b/i, "masked model number"],
      [/\A[\d\s.]*\z/, "no model name"],
      [/\A(unknown|n\/?a|none)\b/i, "no model name"]
    ].freeze

    # Trademark noise and vendor boilerplate.
    TRADEMARKS = /\((?:R|TM|r|tm)\)/.freeze
    LEADING_NOISE = /\A(?:Genuine|Authentic)\s+/i.freeze
    # "12th Gen Intel Core i7-12700K" — the generation is already in the model
    # number, and keeping it would split one chip across two names.
    GENERATION = /\b\d{1,2}(?:st|nd|rd|th)\s+Gen(?:eration)?\s+/i.freeze

    # Core-count suffixes. Spelled out as well as numeric, and AMD writes both
    # "16-Core Processor" and "64-Cores".
    CORE_WORDS = /(?:Dual|Two|Three|Four|Quad|Five|Six|Seven|Eight|Nine|Ten|Twelve|Sixteen)/i.freeze
    CORE_SUFFIX = /[\s,-]+(?:\d{1,3}|#{CORE_WORDS})[\s-]*Cores?(?:\s+Processor)?\s*\z/i.freeze
    TRAILING_PROCESSOR = /[\s-]+(?:Processor|CPU|APU)\s*\z/i.freeze

    # Integrated graphics, which the model number already implies.
    GRAPHICS = /\s+(?:with|w\/)\s+.*?Graphics\s*\z/i.freeze
    APU_GRAPHICS = /\s+APU\s+with\s+.*\z/i.freeze

    # Clock speeds. Reported inconsistently and not part of the part number.
    CLOCK = /\s*@\s*[\d.,]+\s*[GM]Hz\s*\z/i.freeze
    INLINE_CPU = /\s+CPU\s+/i.freeze

    # Words that keep their capitalisation when an all-caps string is recased.
    ACRONYMS = %w[AMD HX HS PRO EPYC APU GHZ XT].freeze
    VENDOR_WORDS = {
      "INTEL" => "Intel", "XEON" => "Xeon", "PLATINUM" => "Platinum", "GOLD" => "Gold",
      "SILVER" => "Silver", "BRONZE" => "Bronze", "CORE" => "Core", "ULTRA" => "Ultra",
      "RYZEN" => "Ryzen", "THREADRIPPER" => "Threadripper", "ATHLON" => "Athlon",
      "PENTIUM" => "Pentium", "CELERON" => "Celeron", "PHENOM" => "Phenom",
      "OPTERON" => "Opteron", "APPLE" => "Apple", "PROCESSOR" => "Processor"
    }.freeze

    def self.call(raw) = new(raw).call

    def initialize(raw)
      @raw = raw.to_s
    end

    def call
      return reject("no model name") if @raw.strip.empty?

      reason = rejection_reason
      return reject(reason) if reason

      name = clean(@raw)
      return reject("no model name") if name.blank? || name.length < 3
      # A name with no model number identifies a brand, not a part. Cloud and
      # virtualised hosts report plenty of these ("Genuine Intel CPU @ 2.20GHz",
      # "Intel Xeon CPU"); pooling them would average unrelated silicon into one
      # row, so they are rejected rather than merged.
      return reject("no model number") unless name.match?(/\d/)

      name = prefix_vendor(name)
      Result.new(name: name, vendor: Cpu.vendor_for(name))
    end

    private

    def reject(reason) = Result.new(rejected_reason: reason)

    def rejection_reason
      REJECT.find { |pattern, _| @raw.match?(pattern) }&.last
    end

    def clean(value)
      value = value.dup
      value.gsub!(TRADEMARKS, "")
      value.sub!(LEADING_NOISE, "")
      value.sub!(APU_GRAPHICS, "")
      value.sub!(GRAPHICS, "")
      value.sub!(CLOCK, "")
      value.sub!(GENERATION, "")
      # Applied before the core suffix so "... 16-Core Processor" loses both.
      value.sub!(CORE_SUFFIX, "")
      value.sub!(TRAILING_PROCESSOR, "")
      # "Intel Xeon CPU W3680" — an infix "CPU" is filler between brand and model.
      value.gsub!(INLINE_CPU, " ")
      value = recase(value)
      value.squeeze(" ").strip.sub(/[,\s-]+\z/, "")
    end

    # Some machines report the name in capitals ("INTEL XEON PLATINUM 8568Y+").
    # Recase only those: a mixed-case string already carries meaningful
    # capitals, like the X in 5950X.
    def recase(value)
      return value unless value == value.upcase && value.match?(/[A-Z]{3,}/)

      value.split(/\s+/).map do |word|
        next word if ACRONYMS.include?(word)
        next VENDOR_WORDS[word] if VENDOR_WORDS.key?(word)
        next word if word.match?(/\d/) # model numbers keep their shape
        word.capitalize
      end.join(" ")
    end

    # Wikidata and the vendors both label parts with the maker in front
    # ("AMD Ryzen 9 5950X"), but plenty of machines omit it. Adding it keeps one
    # chip under one name.
    def prefix_vendor(name)
      vendor = Cpu.vendor_for(name)
      label = Cpu::VENDOR_LABELS[vendor]
      return name if vendor == "other" || name.match?(/\A#{Regexp.escape(label)}\b/i)

      "#{label} #{name}"
    end
  end
end
