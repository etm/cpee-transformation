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

require_relative '../lib/cpee/transformation/transformer' rescue nil
require_relative '../lib/cpee/transformation/bpmn2' rescue nil
require_relative '../lib/cpee/transformation/mermaid' rescue nil

interactive = false
printtree = false

ARGV.options { |opt|
  opt.summary_indent = ' ' * 2
  opt.summary_width = 18
  opt.banner = "Usage:\n#{opt.summary_indent}#{File.basename($0)} FNAME\n"
  opt.on("Options:")
  opt.on("--help", "-h", "This text") { puts opt; exit }
  opt.on("--interactive", "-i", "Interactive mode") { interactive = true }
  opt.on("--tree", "-t", "Print tree") { printtree = true }
  opt.on("")
  opt.on(wrap("[FNAME]","convert cpee bpmn2 in file FNAME to mermaid and output to console."))
  opt.parse!
}

if ARGV.length != 1
  puts ARGV.options
  exit
else
  f = ARGV[0]
end

model = CPEE::Transformation::Source::BPMN2.new(File.read(f))

trans = CPEE::Transformation::Transformer.new(model)
traces = trans.build_traces

if interactive
  puts traces.legend
  puts
  tree = trans.build_tree(true)
else
  tree = trans.build_tree(false)
end

if printtree
  puts tree.to_s
else
  puts trans.generate_model(CPEE::Transformation::Target::Mermaid)
end
