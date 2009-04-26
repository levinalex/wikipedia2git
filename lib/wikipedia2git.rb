require 'httparty'
require 'grit'
require 'pathname'

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
    base_uri "http://en.wikipedia.org/w/api.php"

    def initialize(name)
      @name = name
    end

    def pageid
      @pageid ||= begin
        result = self.class.get('',
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


if __FILE__ == $0
  article = Wikipedia::Article.new(ARGV[0] || "Main Page")
  id = article.pageid
  dir = Pathname.new("cache").join(article.pageid)
  FileUtils.mkdir_p(dir)

  repo = Grit::Repo.init_bare(dir.join("#{article.pageid}.git"))
  last_commit = nil

  article.revisions.each do |r|
    puts [r.timestamp, r.user].join(" - ")

    user = Grit::Actor.new(r.user, r.user)

    ENV["GIT_AUTHOR_DATE"] = r.timestamp.to_s

    index = repo.index
    index.add("article", r.content)
    last_commit = index.commit(r.comment, last_commit, user)
  end
  p last_commit
end