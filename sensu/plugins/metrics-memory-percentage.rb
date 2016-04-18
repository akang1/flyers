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

####*****************************************#####
####Antonio Kang - I modified so it shows free/used memory in percentage AND actual number#####
####*****************************************#####

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

    memNumFunction
    memPctFunction

    ok
  end

  def memNumFunction
    memPct = {}
    meminfo_output.each_line do |line|
      $total = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^MemTotal/)
      memPct['swapTotalNum'] = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^SwapTotal/)
      memPct['swapFreeNum']  = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^SwapFree/)
      $free = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^MemFree/)
      $cached = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^Cached/)
      $buffers = (line.split(/\s+/)[1].to_i * 1024) / 1000000 if line.match(/^Buffers/)
    end

    memPct['swapUsedNum'] = memPct['swapTotalNum'] - memPct['swapFreeNum']
    $used = $total - $free
    memPct['total'] = $total
    memPct['usedWOBuffersCaches'] = $used - ($buffers + $cached)
    memPct['freeWOBuffersCaches'] = $free + ($buffers + $cached)

    memPct.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end
end

def memPctFunction

    memPct = {}
    mempPct = {}

    meminfo_output.each_line do |line|
      $totalPct     = line.split(/\s+/)[1].to_i * 1024 if line =~ /^MemTotal/
      $freePct      = line.split(/\s+/)[1].to_i * 1024 if line =~ /^MemFree/
      $buffersPct   = line.split(/\s+/)[1].to_i * 1024 if line =~ /^Buffers/
      $cachedPct    = line.split(/\s+/)[1].to_i * 1024 if line =~ /^Cached/
      memPct['swapTotalPct'] = line.split(/\s+/)[1].to_i * 1024 if line =~ /^SwapTotal/
      memPct['swapFreePct']  = line.split(/\s+/)[1].to_i * 1024 if line =~ /^SwapFree/
      $dirtyPct     = line.split(/\s+/)[1].to_i * 1024 if line =~ /^Dirty/
    end


    memPct['usedPct'] = $totalPct - $freePct
    memPct['usedMemPct'] = memPct['usedPct'] - ($buffersPct + $cachedPct)
    memPct['freeMemPct'] = $freePct + ($buffersPct + $cachedPct)

    # to prevent division by zero
    swptot = if memPct['swapTotalPct'] == 0
               1
             else
               memPct['swapTotalPct']
             end

    memPct.each do |k, _v|
      # with percentages, used and free are exactly complementary
      # no need to have both
      # the one to drop here is "used" because "free" will
      # stack up neatly to 100% with all the others (except swapUsed)
      # #YELLOW
      mempPct[k] = 100.0 * memPct[k] / $totalPct if k != 'totalPct' && k !~ /swap/ && k != 'usedPct'

      # with percentages, swapUsed and swapFree are exactly complementary
      # no need to have both
      mempPct[k] = 100.0 * memPct[k] / swptot if k != 'swapTotalPct' && k =~ /swap/ && k != 'swapFreePct'
    end

    mempPct.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

  end


  def meminfo_output
    File.open('/proc/meminfo', 'r')
  end
end
