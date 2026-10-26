#!/usr/bin/ruby
# encoding: UTF-8
#
# This file is part of CPEE-TRANSFORMATION.
#
# CPEE-TRANSFORMATION is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# CPEE-TRANSFORMATION is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
# for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with CPEE-TRANSFORMATION (file LICENSE in the main directory).  If not,
# see <http://www.gnu.org/licenses/>.

require 'timeout'
require_relative '../lib/cpee/transformation/transformer' rescue nil
require_relative '../lib/cpee/transformation/cpee' rescue nil
require_relative '../lib/cpee/transformation/mermaid' rescue nil
require_relative '../lib/cpee/transformation/bpmn2' rescue nil

def tprint(f,count,tcount,failed=false)
  base = File.join(File.dirname(f),File.basename(f,File.extname(f)))
  ### prefer bpmn, fall back to cpee xml
  fname, source = if File.exist?(base + '.bpmn')
    [base + '.bpmn', CPEE::Transformation::Source::BPMN2]
  elsif File.exist?(base + '.xml')
    [base + '.xml', CPEE::Transformation::Source::CPEE]
  end
  if fname
    tcount += 1
    begin
      model = source.new(File.read(fname))
      trans = CPEE::Transformation::Transformer.new(model)
      traces = trans.build_traces
      tree = trans.build_tree(false)

      nt = tree.to_s
      ot = File.read(File.join(File.dirname(f),File.basename(f,File.extname(f)) + '.tree'))
      if nt.gsub(/[ \t]+$/,'') == ot.gsub(/[ \t]+$/,'')
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

### control flow elements of a cpee description, as an indented list
SKELETON = %w(loop choose alternative otherwise parallel parallel_branch call manipulate escape terminate stop critical)
def skeleton(node,depth=0,res=[])
  node.children.each do |c|
    next unless c.respond_to?(:qname) && SKELETON.include?(c.qname.name)
    res << ('  ' * depth) + c.qname.name
    skeleton(c,depth + 1,res)
  end
  res
end

def to_cpee(source,text)
  trans = CPEE::Transformation::Transformer.new(source.new(text))
  trans.build_traces
  trans.build_tree(false)
  trans.generate_model(CPEE::Transformation::Target::CPEE)
end

### cpee -> cpee twice has to produce the same structure
def sprint(f,count,tcount)
  tcount += 1
  begin
    p1 = to_cpee(CPEE::Transformation::Source::CPEE,File.read(f))
    p2 = to_cpee(CPEE::Transformation::Source::CPEE,p1)
    if skeleton(XML::Smart.string(p1).root) == skeleton(XML::Smart.string(p2).root)
      puts "Passed (stable): " + f
      count += 1
    else
      puts "Failed (stable): " + f
    end
  rescue StandardError, SystemStackError => e
    puts "Failed (stable): #{f} (#{e.class}: #{e.message.lines.first&.strip})"
  end
  return count, tcount
end

### source -> target has to work (and finish)
def gprint(f,source,target,what,count,tcount)
  tcount += 1
  begin
    Timeout.timeout(10) do
      trans = CPEE::Transformation::Transformer.new(source.new(File.read(f)))
      trans.build_traces
      trans.build_tree(false)
      trans.generate_model(target)
    end
    puts "Passed (#{what}): " + f
    count += 1
  rescue Timeout::Error
    puts "Failed (#{what}): #{f} (does not finish)"
  rescue StandardError, SystemStackError => e
    puts "Failed (#{what}): #{f} (#{e.class}: #{e.message.lines.first&.strip})"
  end
  return count, tcount
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
  src = CPEE::Transformation::Source
  tgt = CPEE::Transformation::Target
  Dir.glob(File.join(__dir__,'*.xml')).each do |f|
    count, tcount = sprint(f,count,tcount)
    count, tcount = gprint(f,src::CPEE,tgt::Mermaid,'cpee to mermaid',count,tcount)
  end
  Dir.glob(File.join(__dir__,'*.bpmn')).each do |f|
    count, tcount = gprint(f,src::BPMN2,tgt::CPEE,'bpmn to cpee',count,tcount)
  end
  Dir.glob(File.join(__dir__,'*.mmd')).each do |f|
    count, tcount = gprint(f,src::Mermaid,tgt::CPEE,'mermaid to cpee',count,tcount)
    count, tcount = gprint(f,src::Mermaid,tgt::Mermaid,'mermaid to mermaid',count,tcount)
  end
end

puts "-" * 78
puts "Summary: #{count}/#{tcount} passed"
