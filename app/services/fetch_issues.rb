require "graphql/client"
require "graphql/client/http"

class FetchIssues
  attr_reader :total

  def initialize(repo, labels: nil, state: 'OPEN', since: nil)
    @repo = repo
    @options = {labels: labels, state: state, since: since}
    @total = 0
  end

  def run
    cache_fetch do
      results, cursor = fetch_all(nil)
      Padrino.logger.info(results.first['createdAt'])
      Padrino.logger.info(results.last['createdAt'])

      while results.size < @total do

        new_results, cursor = fetch_all(cursor)
        Padrino.logger.info(new_results.first['createdAt'])
        Padrino.logger.info(new_results.last['createdAt'])
        results += new_results
      end

      results
    end
  end

  private

  def cache_fetch
    key = "FetchIssues:#{@repo}:#{@options.values.flatten.compact.join(':')}:v6"
    return Padrino.cache.load(key) if Padrino.cache.key?(key)
    Padrino.cache.store(key, yield, expires: 3600 * 12)
  end

  def fetch_all(cursor)
    response = graphql.query(full_query(cursor))
    data = response.data.to_h
    @total = data.dig('repository','issues', 'totalCount')

    results = data.dig('repository', 'issues', 'edges').map do |node|
      cursor = node['cursor']
      node['node']
    end.map do |node|
      node.merge('labels' => extract_labels(node))
    end
    [results, cursor]
  end

  def extract_labels(node)
    node.dig('labels', 'edges').map{|label| label['node']}.map{|label| label['name']}
  end

  def full_query(cursor)
    Padrino.logger.info(cursor || 'null')
    filters = []
    filters << "orderBy: {field: CREATED_AT, direction: DESC}"
    filters << "labels: #{@options[:labels]}" if @options[:labels]
    filters << "first: 100"
    filters << "after: \"#{cursor}\"" if cursor
    filters << "states: #{@options[:state]}" if @options[:state]

    <<~GRAPHQL
    {
      repository(name: "#{repo_name}", owner: "#{repo_owner}") {
        issues(#{filters.join(', ')}) {
          totalCount
          edges {
            cursor
            node {
              title
              url
              createdAt
              closedAt
              state
              labels(first: 10) {
                edges {
                  node {
                    name
                  }
                }
              }
            }
          }
        }
      }
    }
    GRAPHQL
  end

  def repo_name
    @repo.split('/').last
  end

  def repo_owner
    @repo.split('/').first
  end

  def graphql
    @@graphql = begin
      Graphlient::Client.new('https://api.github.com/graphql',
        headers: {
          Authorization:  "bearer [YOUR KEY HERE]"
        }
      )
    end
  end
end
