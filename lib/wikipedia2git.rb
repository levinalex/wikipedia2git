require 'httparty'

module Wikipedia

  class Revisions
    include HTTParty
    include Enumerable

    base_uri "http://en.wikipedia.org/w/api.php"
    default_params :action => :query,
                   :prop => :revisions,
                   :rvdir => :newer,
                    #:rvprop => :content,
                   :rvlimit => 50,
                   :format => :json

    def initialize(pageid)
      @pageid = pageid
      @revs = []
    end

    def each
      nextquery = {}
      while true
        result = self.class.get('', :query => {:pageids => @pageid}.merge(nextquery))
        @revs = result["query"]["pages"][@pageid]["revisions"].each do |rev|
          yield rev
        end
        if result["query-continue"]
          nextquery = result["query-continue"]["revisions"]
        else
          return
        end
      end
      sleep 1
    end
  end

  class Article
    include HTTParty
    base_uri "http://en.wikipedia.org"

    def initialize(name)
      @name = name
    end

    def pageid
      @pageid ||= begin
        result = self.class.get('/w/api.php',
          :query => {
            :action => :query ,
            :prop => :revisions,
            :titles => @name,
            :format => :json })
        result["query"]["pages"].keys.first
      end
    end

    def revisions
      Revisions.new(pageid)
    end

  end
end

if __FILE__ == $0
  article = Wikipedia::Article.new(ARGV[0] || "Eel")
  article.revisions.each { |r| puts r.inspect }
end