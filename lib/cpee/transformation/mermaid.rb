# encoding: UTF-8
#
# This file is part of cpee-transformation.
#
# cpee-transformation is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# cpee-transformation is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License
# for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with cpee-transformation (file COPYING in the main directory).  If not,
# see <http://www.gnu.org/licenses/>.

require_relative 'structures'

module CPEE

  module Transformation

    module Source

      class Mermaid
        attr_reader :tree, :start, :dataelements, :endpoints, :graph, :traces

         def initialize(text) #{{{
          @tree = Tree.new
          @start = nil

          @dataelements = {}
          @endpoints = {}
          @graph = Graph.new

          extract_nodelink(text)

          @traces = Traces.new [[@start]]
        end #}}}

        def extract_nodelink(text) #{{{
          # "-----"
          # 700
          # "sid-2A054430-1FC6-495B-B993-C52D7E8F4C5A"
          # :startEvent
          # ""
          # 0.0
          # 1.0
          # "-----"

          # :tasj -> task
          # :parallelGateway -> parallelgateway
          # :exclusiveGateway -> exclusivegateway
          # :eventBasedGateway -> eventbasedgateway
          # :inclusiveGateway -> inclusivegateway
          # :endEvent -> endevent
          # :startEvent -> startevent

          text.each_line do |line|
            if line =~ /-->/
              l, r = line.strip.split(/-->(|[^|]+|)?/)
              a = line.strip.split(/-->(\|([^|]*)\|)/)
              p a
              lid,ltype,llabel = l.split(':',3)
              rid,rtype,rlabel = r.split(':',3)
              p "---"
              # n = Node.new(0,e.attributes['id'],e.qname.name.to_sym,e.attributes['name'].strip,e.find('count(bm:incoming)'),e.find('count(bm:outgoing)'))

            end
          end

          #doc.find("/bm:definitions/bm:process/bm:*[@id and @name and not(@itemSubjectRef) and not(name()='sequenceFlow')]").each do |e|
          #  n = Node.new(self.object_id,e.attributes['id'],e.qname.name.to_sym,e.attributes['name'].strip,e.find('count(bm:incoming)'),e.find('count(bm:outgoing)'))

          #  if e.attributes['scriptFormat'] != ''
          #    n.script_type = e.attributes['scriptFormat']
          #  end

          #  e.find("bm:property[@name='cpee:endpoint']/@itemSubjectRef").each do |ep|
          #    n.endpoints << ep.value
          #  end
          #  e.find("bm:property[@name='cpee:method']/@itemSubjectRef").each do |m|
          #    n.methods << m.value
          #  end
          #  e.find("bm:script").each do |s|
          #    n.script ||= ''
          #    n.script << s.text.strip
          #  end
          #  e.find("bm:ioSpecification/bm:dataInput").each do |a|
          #    name = a.attributes['name']
          #    value = a.attributes['itemSubjectRef']
          #    if @dataelements.keys.include?(value)
          #      n.parameters[name] = 'data.' + value
          #    else
          #      n.parameters[name] = value
          #    end
          #  end
          #  e.find("bm:ioSpecification/bm:dataOutput").each do |a|
          #    ref = a.attributes['id']
          #    e.find("bm:dataOutputAssociation[bm:sourceRef=\"#{ref}\"]").each do |d|
          #      n.script_var = ref
          #      n.script_id = d.find("string(bm:targetRef)")
          #    end
          #  end

          #  @graph.add_node n
          #  @start = n if n.type == :startEvent && @start == nil
          #end

          ## extract all sequences to a links
          #doc.find("/bm:definitions/bm:process/bm:sequenceFlow").each do |e|
          #  source = e.attributes['sourceRef']
          #  target = e.attributes['targetRef']
          #  cond = e.find('bm:conditionExpression')
          #  @graph.add_link Link.new(source, target, cond.empty? ? nil : cond.first.text.strip)
          #end

          #@graph.clean_up do |node|
          #  if node.type == :scriptTask && (x = @graph.find_script_id(node.id)).any?
          #    x.each do |k,n|
          #      n.script = node.script
          #      n.script_type = node.script_type
          #    end
          #    true
          #  else
          #    false
          #  end
          #end
        end #}}}

      end

    end


  end

end
