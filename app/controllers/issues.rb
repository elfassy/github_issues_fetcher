require_relative '../services/fetch_issues'

GithubIssues::App.controllers :issues do

  get :index do
    issues = {}
    FetchIssues.new('Shopify/shopify', labels: ['Component: Payment Processing']).run.each do |issue|
      labels = issue['labels'] - ['Component: Payment Processing', 'Low Priority', 'Medium Priority', 'High Priority', 'Bug', 'Support', 'Dev - Low Effort', 'bugsnag', 'Icebox', 'Plus', 'Support - Low Impact', 'Feature Request', 'Technical Debt', 'FED - Low effort', 'Quick Win']
      labels = ['None'] if labels.empty?

      issue['title'] = "[Low Priority] " + issue['title'] if issue['labels'].include?('Low Priority') || issue['labels'].include?('Support - Low Impact')
      issue['title'] = "[High Priority] " + issue['title'] if issue['labels'].include?('High Priority') || issue['labels'].include?('Plus')
      issue['title'] = "[Medium Priority] " + issue['title'] if issue['labels'].include?('Medium Priority')
      issue['title'] = "[Icebox] " + issue['title'] if issue['labels'].include?('Icebox')
      issue['title'] = "[Bug] " + issue['title'] if issue['labels'].include?('Bug') || issue['labels'].include?('bugsnag')
      issue['title'] = "[Feature Request] " + issue['title'] if issue['labels'].include?('Feature Request')
      issue['title'] = "[Technical Debt] " + issue['title'] if issue['labels'].include?('Technical Debt')


      labels.each do |label|
        issues[label] ||= []
        issues[label] << issue.except('labels')
      end
    end
    FetchIssues.new('Shopify/Money').run.each do |issue|
      issues['Currency'] ||= []
      issues['Currency'] << issue.except('labels')
    end
    @issues = issues

    render 'index'
  end

  get :chart do
    total_open = 0
    total_closed = 0
    open_issues = []
    closed_issues = []

    all_issues = FetchIssues.new('Shopify/shopify', labels: ['Component: Payment Processing'], state: nil).run

    all_closed_issues = all_issues.select{|x| x['state'] == 'CLOSED'}

    all_closed_issues.group_by_month{|x| x['closedAt']}.each do |day, issues|
      total_closed += issues.size
      next if day < Time.parse('2017-01-01')
      closed_issues << [day, total_closed]
    end


    all_issues.group_by_month{|x| x['createdAt']}.each do |day, issues|
      total_open += issues.size
      next if day < Time.parse('2017-01-01')
      open_issues << [day, total_open]
    end


    @graph1 = [{name: 'OPEN', data: open_issues},{name: 'CLOSED', data: closed_issues}]


    all_closed_issues.group_by_month{|x| x['closedAt']}.each do |day, issues|
      issues.sum
    end

    # @graph2 = open_issues
    render 'chart'
  end

end
