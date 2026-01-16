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

count = 0
tcount = 0
Dir.glob(File.join(__dir__,'**/*.tree')).each do |f|
  fname2 = File.join(File.dirname(f),File.basename(f,'.tree') + '.mmd')
  fname3 = File.join(File.dirname(f),File.basename(f,'.tree') + '.xml')

  if File.exist?(fname = File.join(File.dirname(f),File.basename(f,'.tree') + '.bpmn'))
    tcount += 1
    begin
      model = CPEE::Transformation::Source::BPMN2.new(File.read(fname))
      trans = CPEE::Transformation::Transformer.new(model)
      traces = trans.build_traces
      tree = trans.build_tree(false)

      nt = tree.to_s
      ot = File.read(f)
      if nt == ot
        puts "Passed: " + fname
        count += 1
      else
        puts "Failed: " + fname
        puts nt
        puts ot
      end
    rescue SystemStackError
      puts "Failed: " + fname + "(Stack Level too deep)"
    end

  end
end

puts "-" * 25
puts "Summary: #{count}/#{tcount} passed"
