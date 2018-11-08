require_relative '../services/fetch_issues'
require 'active_support/inflector'

GithubIssues::App.controllers :issues do

  get :index do
    issues = {}
    FetchIssues.new('Shopify/shopify', labels: ['Component: Payment Processing']).run.each do |issue|
      labels = issue['labels'] - ['Component: Payment Processing', 'Bootstrap', 'Low Priority', 'Medium Priority', 'High Priority', 'Bug', 'Support', 'Dev - Low Effort', 'bugsnag', 'Icebox', 'Plus', 'Support - Low Impact', 'Technical Debt', 'FED - Low effort', 'Quick Win']


      issue['title'] = "[Low Priority] " + issue['title'] if issue['labels'].include?('Low Priority') || issue['labels'].include?('Support - Low Impact')
      issue['title'] = "[High Priority] " + issue['title'] if issue['labels'].include?('High Priority') || issue['labels'].include?('Plus')
      issue['title'] = "[Medium Priority] " + issue['title'] if issue['labels'].include?('Medium Priority')
      issue['title'] = "[Icebox] " + issue['title'] if issue['labels'].include?('Icebox')
      issue['title'] = "[Bug] " + issue['title'] if issue['labels'].include?('Bug') || issue['labels'].include?('bugsnag')
      # issue['title'] = "[Feature Request] " + issue['title'] if issue['labels'].include?('Feature Request')
      issue['title'] = "[Technical Debt] " + issue['title'] if issue['labels'].include?('Technical Debt')

      labels = ['None'] if labels.empty?
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

    months = (Date.parse('2017-01-01')...Date.today).group_by_month{|x| x}.keys

    all_issues = FetchIssues.new('Shopify/shopify', labels: ['Component: Payment Processing'], state: nil).run
    all_issues = all_issues.select{|x| x['labels'].include?(params[:filter])} if params[:filter]

    issues_closed_by_month = all_issues.select{|x| x['state'] == 'CLOSED'}.group_by_month{|x| x['closedAt']}
    issues_created_by_month = all_issues.group_by_month{|x| x['createdAt']}

    months.each do |month|
      total_closed += issues_closed_by_month[month]&.size || 0
      closed_issues << [month.strftime("%b %Y"), total_closed]

      total_open += issues_created_by_month[month]&.size || 0
      open_issues << [month.strftime("%b %Y"), total_open - total_closed]
    end


    @graph1 = [{name: 'CLOSED', data: closed_issues},{name: 'OPEN', data: open_issues}]

    @graph2 = []

    months.each do |month|
      issues = issues_closed_by_month[month]
      avg_time = (issues.sum {|issue| (Time.parse(issue['closedAt']) - Time.parse(issue['createdAt']))} / 3600 / issues.size / 24).to_i if issues && issues.size != 0
      @graph2 << [month.strftime("%b %Y"), avg_time]
    end

    graph3_avg = []
    graph3_med = []
    months.each do |month|
      issues = all_issues.select{|x| x['state'] == 'OPEN' && Date.parse(x['createdAt']) <= month.end_of_month}
      avg_time = (issues.sum {|issue| (month.end_of_month - Date.parse(issue['createdAt']))} / issues.size ).to_i if issues && issues.size != 0
      graph3_avg << [month.strftime("%b %Y"), avg_time]
      med_time = median(issues.map {|issue| (month.end_of_month - Date.parse(issue['createdAt']))}).to_i if issues && issues.size != 0
      graph3_med << [month.strftime("%b %Y"), med_time]
    end

    @graph3 = [{name: 'AVG', data: graph3_avg},{name: 'MEDIAN', data: graph3_med}]


    @graph4 = []
    months.each do |month|
      rate = (issues_closed_by_month[month]&.size || 0) - (issues_created_by_month[month]&.size || 0)
      @graph4 << [month.strftime("%b %Y"), rate]
    end

    @stats = {
      avg_net_closed_per_month: (@graph4.reduce(0) {|total, month| total + month[1]} /  @graph4.size.to_f).round(2),
      avg_open_per_month: (months.reduce(0) {|total, month| total + (issues_created_by_month[month]&.size || 0)} /  months.size.to_f).round(2),
      avg_closed_per_month: (months.reduce(0) {|total, month| total + (issues_closed_by_month[month]&.size || 0)} /  months.size.to_f).round(2)
    }

    render 'chart'
  end

  private

  define_method :median do |array|
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

end
