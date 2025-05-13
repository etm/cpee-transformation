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

require_relative '../lib/cpee/transformation/transformer'
require_relative '../lib/cpee/transformation/cpee'

Dir.chdir(File.expand_path(File.dirname(__FILE__)))
f = "Test 16.xml"

model = CPEE::Transformation::Source::CPEE.new(File.read(f))

trans = CPEE::Transformation::Transformer.new(model)
traces = trans.build_traces
puts traces.legend

tree = trans.build_tree(true)
xml = trans.generate_model(CPEE::Transformation::Target::CPEE)

# p xml.to_s

puts 'do "xmllint test.xml" for happiness. or not.'
File.write(File.expand_path(File.dirname(__FILE__) + '/test.xml'),xml.to_s)
