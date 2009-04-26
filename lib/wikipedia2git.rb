require 'httparty'
require 'grit'

class String
  def excerpt(len = 30)
    str = self.gsub(/[^a-z0-9 ]/i, "")
    if str.length < len
      str
    else
      str[0..len] + "..."
    end
  end
end

class NilClass
  def excerpt
    nil
  end
end

module Wikipedia

  class Revision
    def initialize(article, revision)
      @article = article
      @revision = revision
    end

    %w(timestamp user revid anon comment).each do |m|
      define_method(m) do
        @revision[m]
      end
    end

    def content
      @revision["*"]
    end

    def timestamp
      @revision["timestamp"]
    end
  end

  class Revisions
    include HTTParty
    include Enumerable

    base_uri "http://en.wikipedia.org/w/api.php"
    default_params :action => :query,
                   :prop => :revisions,
                   :rvdir => :newer,
                   :rvprop => [:content, :timestamp, :user, :revid, :comment].join("|"),
                   :rvlimit => 50,
                   :format => :json

    def initialize(article)
      @article = article
      @pageid = article.pageid
      @revs = []
    end

    def each
      nextquery = {}
      while true
        result = self.class.get('', :query => {:pageids => @pageid}.merge(nextquery))
        $stderr.puts result.inspect
        @revs = result["query"]["pages"][@pageid]["revisions"].each do |rev|
          yield Revision.new(@article, rev)
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
      Revisions.new(self)
    end

  end
end

class Time

  class << self
  def self.now
    old_now - 60*60*24*360
  end
  alias_method :old_now, :now
  end
end

if __FILE__ == $0
  article = Wikipedia::Article.new(ARGV[0] || "Eel")
  repo = Grit::Repo.init_bare("/Users/levin/grit.git")
  last_commit = nil # repo.log.first rescue nil

  article.revisions.each do |r|
    p [r.timestamp, "%-40s" % r.comment.excerpt, "%-40s" % r.content.excerpt, r.user].join(" - ")

    user = Grit::Actor.new(r.user, r.user)
    # last_tree = last_commit.tree.id rescue nil

    # index = repo.index
    # index.read_tree(last_tree) if last_tree
    index = repo.index
    index.add("article", r.content)
    last_commit = index.commit(r.comment, last_commit, user)
  end
  p last_commit
end