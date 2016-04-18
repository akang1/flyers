#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   metrics-memory
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   ./metrics-memory.rb
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'

class MemoryGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.memory"
  def run
    # Metrics borrowed from hoardd: https://github.com/coredump/hoardd

    mem = metrics_hash

    mem.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

    ok
  end

  def metrics_hash
    mem = {}
    meminfo_output.each_line do |line|
      $total = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^MemTotal/)
      mem['swapTotal'] = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^SwapTotal/)
      mem['swapFree']  = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^SwapFree/)
      $free = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^MemFree/)
      $cached = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^Cached/)
      $buffers = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^Buffers/)
    end

    mem['swapUsed'] = mem['swapTotal'] - mem['swapFree']
    $used = $total - $free
    mem['total'] = $total
    mem['usedWOBuffersCaches'] = $used - ($buffers + $cached)
    mem['freeWOBuffersCaches'] = $free + ($buffers + $cached)

    mem
  end

  def meminfo_output
    File.open('/proc/meminfo', 'r')
  end
end
