#!/usr/bin/ruby
# encoding: UTF-8
#
# This file is part of cpee-transformation.
#
# cpee-transformation is free software: you can redistribute it and/or modify it under the terms
# of the GNU Lesser General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# cpee-transformation is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along with
# cpee-transformation (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require_relative '../lib/cpee/transformation/transformer' rescue nil
require_relative '../lib/cpee/transformation/cpee' rescue nil
require_relative '../lib/cpee/transformation/mermaid' rescue nil
require_relative '../lib/cpee/transformation/bpmn2' rescue nil

def tprint(f,count,tcount,failed=false)
  if File.exist?(fname = File.join(File.dirname(f),File.basename(f,File.extname(f)) + '.bpmn'))
    tcount += 1
    begin
      model = CPEE::Transformation::Source::BPMN2.new(File.read(fname))
      trans = CPEE::Transformation::Transformer.new(model)
      traces = trans.build_traces
      tree = trans.build_tree(false)

      nt = tree.to_s
      ot = File.read(File.join(File.dirname(f),File.basename(f,File.extname(f)) + '.tree'))
      if nt == ot
        puts "Passed: " + fname
        count += 1
        failed = false
      else
        puts '-' * 78 unless failed
        puts 'Failed: ' + fname
        puts nt
        puts ot
        puts '-' * 78
        failed = true
      end
    rescue SystemStackError
      puts "Failed: " + fname + "(Stack Level too deep)"
      failed = true
    end
  end
  return count, tcount, failed
end

count = 0
tcount = 0
failed = false
if ARGV[0] && File.exist?(ARGV[0])
  count, tcount = tprint(ARGV[0],count,tcount)
else
  Dir.glob(File.join(__dir__,'**/*.tree')).each do |f|
    count, tcount, failed = tprint(f,count,tcount, failed)
  end
end

puts "-" * 78
puts "Summary: #{count}/#{tcount} passed"
