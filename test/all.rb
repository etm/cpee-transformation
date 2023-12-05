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
# PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along with
# cpee-transformation (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require_relative '../lib/cpee/transformation/bpmn2'
require_relative '../lib/cpee/transformation/transformer'
require_relative '../lib/cpee/transformation/cpee'

Dir.chdir(File.expand_path(File.dirname(__FILE__)))
Dir["*.bpmn"].each do |f|
  print ' ==> ' + f + ' -> '
  begin
    bpmn2 = CPEE::Transformation::Source::BPMN2.new(File.read(f))
    trans = CPEE::Transformation::Transformer.new(bpmn2)
    trans.build_traces
    tree = trans.build_tree(false).to_s(false)
    xml = trans.generate_model(CPEE::Transformation::Target::CPEE)
    fname = File.basename(f,'.bpmn')
    File.write(fname + '.tree',tree)
    File.write(fname + '.xml',xml)
    puts 'success'
  rescue => e
    puts 'failed'
    puts e.message
    puts e.backtrace
  end
end
