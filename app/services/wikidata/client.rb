require "net/http"

module Wikidata
  # Thin SPARQL client for the public Wikidata endpoint.
  class Client
    ENDPOINT = "https://query.wikidata.org/sparql".freeze
    # Wikidata asks for a descriptive agent so they can contact operators of
    # misbehaving clients. Sending a real one is a condition of using it.
    USER_AGENT = "cpu-compare/1.0 (Blender Open Data CPU comparison; spec ingest)".freeze

    class QueryFailed < StandardError; end

    def initialize(endpoint: ENDPOINT, timeout: 120)
      @endpoint = endpoint
      @timeout = timeout
    end

    # Returns the bindings array, each a hash of name => { "value" => ... }.
    def select(sparql)
      uri = URI(@endpoint)
      uri.query = URI.encode_www_form(query: sparql)

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/sparql-results+json"
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                                 read_timeout: @timeout, open_timeout: 30) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise QueryFailed, "Wikidata returned #{response.code}: #{response.body.to_s.truncate(300)}"
      end

      JSON.parse(response.body).dig("results", "bindings") || []
    end
  end
end
