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

def wrap(s1, s2, width=78, indent=ARGV.options.summary_width + 3)
  lines = []
  s = ARGV.options.summary_indent + s1 + ' ' * (indent - s1.length - ARGV.options.summary_indent.length) + s2
  line, s = s[0..indent-2], s[indent..-1]
  s.split(/\n/).each do |ss|
    ss.split(/[ \t]+/).each do |word|
      if line.size + word.size >= width
        lines << line
        line = (" " * (indent)) + word
      else
        line << " " << word
      end
    end
    lines << line if line
    line = (" " * (indent-1))
  end
  return lines.join("\n")
end

require 'optparse'
require 'timeout'
require_relative '../lib/cpee/transformation/transformer' rescue nil
require_relative '../lib/cpee/transformation/cpee' rescue nil
require_relative '../lib/cpee/transformation/mermaid' rescue nil


def mermaid_to_cpee(f)
  model = CPEE::Transformation::Source::Mermaid.new(File.read(f))
  trans = CPEE::Transformation::Transformer.new(model)
  traces = trans.build_traces
  tree = trans.build_tree(false)
  return [traces, trans.generate_model(CPEE::Transformation::Target::CPEE)]
end

def cpee_to_mermaid(model)
  Timeout::timeout(10) do
    model = CPEE::Transformation::Source::CPEE.new(model)
    trans = CPEE::Transformation::Transformer.new(model)
    traces = trans.build_traces
    tree = trans.build_tree(false)
    return trans.generate_model(CPEE::Transformation::Target::Mermaid)
  end
rescue Timeout::Error
  return 0
end

def build_traces(mermaid)
  Timeout::timeout(10) do
    model = CPEE::Transformation::Source::Mermaid.new(mermaid)
    trans = CPEE::Transformation::Transformer.new(model)
    return trans.build_traces.length()
  end
rescue
  return 0
end

#sets = ['pet']
sets = ['domains','mad150','realset','sapsam']
sets.each do |s|
  root_dir = File.join('..', '..', 'llm-generated-models','gpt-4o',s)
  p ['Dataset:   ',s]
  Dir.foreach(root_dir) do |file_name|
    #p ['*************', file_name]
    next if file_name == '.' or file_name == '..' or file_name == 'cpee' or file_name == 'mermaid_2'
    orig_trace, cpee_tree = mermaid_to_cpee(File.join(root_dir,file_name))
    new_mermaid = cpee_to_mermaid(cpee_tree)
    if new_mermaid == 0
      p ["Error",  file_name]
    else
      if  orig_trace.length() ==  build_traces(new_mermaid)
        #puts 'compare'
      else
        p ["Error",  file_name]
      end
    end
  end
end

