#!/usr/bin/env ruby

require 'csv'
require 'descriptive-statistics'

csv_file = ARGV[0] or raise 'Must provide a CSV filename'
rows = CSV.new(File.new(csv_file), headers: true).read or raise 'Invalid CSV data'

FOUR_MONTHS_AGO = (DateTime.now - (30 * 4)).freeze

class GitHubPullRequestInfo
  attr_reader :repo, :number, :user, :title, :state, :created, :updated, :merged, :url, :time_to_merge

  DATE_TIME_FORMAT = '%m/%d/%y %H:%M:%S %Z'.freeze

  def self.parse_datetime(value)
    return value unless value && value != ''

    DateTime.strptime("#{value} Pacific Time", DATE_TIME_FORMAT)
  end

  def initialize(csv_row)
    csv_row.is_a?(CSV::Row) or csv_row.is_a?(Hash) or raise 'Invalid parameter'

    @repo = csv_row['Repository']
    @number = csv_row['#']
    @user = csv_row['User']
    @title = csv_row['Title']
    @state = csv_row['State']
    @created = self.class.parse_datetime(csv_row['Created'])
    @updated = self.class.parse_datetime(csv_row['Updated'])
    @merged = self.class.parse_datetime(csv_row['Merged'])
    @url = csv_row['URL']
    @time_to_merge = @merged ? (@merged - @created).to_f.floor : nil
  end

  def to_h
    {
      :repo => @repo,
      :number => @number,
      :user => @user,
      :title => @title,
      :state => @state,
      :created => @created,
      :updated => @updated,
      :merged => @merged,
      :time_to_merge => @time_to_merge,
      :url => @url,
    }
  end

  def to_s
    to_h.to_s
  end
end

SEP = "------------------------------------------------".freeze
def report(stats, description, sample_count)
  puts SEP
  puts 'Time To Merge Stats'
  puts description
  puts "n = #{sample_count}"
  puts SEP
  puts format(' Range: %2d - %2d days', stats.min, stats.max)
  puts format('  Mean: %5.2f', stats.mean)
  puts format('Median: %5.2f', stats.median)
  puts format('StdDev: %5.2f', stats.standard_deviation)
  puts SEP
  puts "Percentiles:"
  [50, 60, 70, 80, 90, 95].each_slice(3) do |ptiles|
    puts ptiles.map {|n|
      format("#{n}%% <= %2d d", stats.value_from_percentile(n))
    }.join('     ')
  end
  puts SEP
  puts 'Percentage of Merges Within:'
  [0, 1, 2, 3, 5, 7, 10].each_slice(2) do |ptiles|
    puts ptiles.map {|n|
      format("%2d days: %2d%%", n, (stats.percentile_from_value(n) rescue '-1'))
    }.join('     ')
  end
  puts SEP
  puts
end

records = rows.map {|r| GitHubPullRequestInfo.new(r) }
sample = records.select { |pr| pr.created && pr.created > FOUR_MONTHS_AGO } #and (!pr.time_to_merge or pr.time_to_merge < 30) }

def ttm_data(data, minimum_ttm = 0)
  return data.select {|pr|
    (pr.time_to_merge or 0) >= minimum_ttm
  }.map(&:time_to_merge).compact
end

puts

all_sample = ttm_data(sample)
stats_all = DescriptiveStatistics::Stats.new(all_sample)
report(stats_all, 'All Merges (Last 4 months)', all_sample.count)

nsd_sample = ttm_data(sample, 1)
stats_not_same_day = DescriptiveStatistics::Stats.new(nsd_sample)
report(stats_not_same_day, 'PRs taking >0 days (Last 4 months)', nsd_sample.count)

tdp_sample = ttm_data(sample, 3)
stats_three_days_plus = DescriptiveStatistics::Stats.new(tdp_sample)
report(stats_three_days_plus, 'PRs taking >2 days (Last 4 months)', tdp_sample.count)

exit 0
