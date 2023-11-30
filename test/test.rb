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

require 'rubygems'
require File.expand_path(File.dirname(__FILE__) + '/../../lib/cpee/formation/bpmn2')
require File.expand_path(File.dirname(__FILE__) + '/../../lib/cpee/formation/cpee')
require 'pp'

Dir.chdir(File.expand_path(File.dirname(__FILE__)))
f = "Test 16.bpmn"

bpmn2 = CPEE::Transformation::Source::BPMN2.new(File.read(f))

#p bpmn2.dataelements
#p bpmn2.endpoints

trans = CPEE::Transformation::Transformer(bpmn2)
traces = trans.build_traces
puts trans.legend

tree = trans.build_tree(true).to_s
xml = trans.generate_model(CPEE::Transformation::Target::CPEE)

# p xml.to_s

puts 'do "xmllint test.xml" for happiness. or not.'
File.write(File.expand_path(File.dirname(__FILE__) + '/test.xml'),xml.to_s)
