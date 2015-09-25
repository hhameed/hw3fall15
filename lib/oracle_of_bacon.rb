require 'byebug'                # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    if @from == @to
      self.errors.add(:from, 'cannot be the same as To')
    end
  end

  def initialize(api_key='')
    @to = "Kevin Bacon"
    @from = @to
    @api_key = api_key
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      raise NetworkError.new(e.message)
    end
    Response.new(xml)
  end

  def make_uri_from_arguments
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=#{CGI.escape(@api_key)}&a=#{CGI.escape(@to)}&b=#{CGI.escape(@from)}"
  end
      
  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if ! @doc.xpath('/error').empty?
        parse_error_response
      elsif ! @doc.xpath('/link').empty?
        parse_graph_response
      elsif ! @doc.xpath('/spellcheck').empty?
        parse_spellcheck_response
      else
        parse_unknown_response
      end
    end
    def parse_error_response
      @type = :error
      @data = 'Unauthorized access'
    end
    def parse_unknown_response
      @type = :unknown
      @data = 'Unknown response'
    end
    def parse_graph_response
      @type = :graph
      actors = @doc.xpath('/link/actor').map{|i| i.text}
      movies = @doc.xpath('/link/movie').map{|i| i.text}
      @data = actors.zip(movies).flatten.compact
    end
    def parse_spellcheck_response
      @type = :spellcheck
      @data = @doc.xpath('/spellcheck/match').map{|i| i.text}
    end
  end
end