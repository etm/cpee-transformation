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
require 'xml/smart'

module CPEE

  module Transformation

    module Source

      class BPMN2
        attr_reader :tree, :start, :dataelements, :endpoints, :graph, :traces

         def initialize(xml) #{{{
          Node.class_variable_set(:@@niceid,  {})

          @tree = Tree.new
          @start = nil

          doc = XML::Smart.string(xml)
          doc.register_namespace 'bm',  "http://www.omg.org/spec/BPMN/20100524/MODEL"

          @dataelements = {}
          @endpoints = {}
          @graph = Graph.new

          extract_dataelements(doc)
          extract_endpoints(doc)
          extract_nodelink(doc)

          if @start.nil?
            @traces = Traces.new [[]]
          else
            @traces = Traces.new [[@start]]
          end
        end #}}}

        def extract_dataelements(doc) #{{{
          doc.find("/bm:definitions/bm:process/bm:property[bm:dataState/@name='cpee:dataelement']").each do |ref|
            if ref.attributes['itemSubjectRef']
              doc.find("/bm:definitions/bm:itemDefinition[@id=\"" + ref.attributes['itemSubjectRef'] + "\"]").each do |sref|
                @dataelements[ref.attributes['name']] = sref.attributes['structureRef'].to_s
              end
            else
              @dataelements[ref.attributes['name']] = ''
            end
          end
        end #}}}

        def extract_endpoints(doc) #{{{
          doc.find("/bm:definitions/bm:process/bm:property[bm:dataState/@name='cpee:endpoint']/@itemSubjectRef").each do |ref|
            doc.find("/bm:definitions/bm:itemDefinition[@id=\"" + ref.value + "\"]/@structureRef").each do |sref|
              @endpoints[ref.value] = sref.value
            end
          end
        end #}}}

        def extract_nodelink(doc) #{{{
          doc.find("/bm:definitions/bm:process/bm:*[@id and @name and not(@itemSubjectRef) and not(name()='sequenceFlow')]").each do |e|
            n = Node.new(self.object_id,e.attributes['id'],e.qname.name.to_sym,e.attributes['name'].strip,e.find('count(bm:incoming)'),e.find('count(bm:outgoing)'))

            if e.attributes['scriptFormat'] != ''
              n.script_type = e.attributes['scriptFormat']
            end

            e.find("bm:property[@name='cpee:endpoint']/@itemSubjectRef").each do |ep|
              n.endpoints << ep.value
            end
            e.find("bm:property[@name='cpee:method']/@itemSubjectRef").each do |m|
              n.methods << m.value
            end
            e.find("bm:script").each do |s|
              n.script ||= ''
              n.script << s.text.strip
            end
            e.find("bm:ioSpecification/bm:dataInput").each do |a|
              name = a.attributes['name']
              value = a.attributes['itemSubjectRef']
              if @dataelements.keys.include?(value)
                n.arguments[name] = 'data.' + value
              else
                n.arguments[name] = value
              end
            end
            e.find("bm:ioSpecification/bm:dataOutput").each do |a|
              ref = a.attributes['id']
              e.find("bm:dataOutputAssociation[bm:sourceRef=\"#{ref}\"]").each do |d|
                n.script_var = ref
                n.script_id = d.find("string(bm:targetRef)")
              end
            end

            @graph.add_node n
            @start = n if n.type == :startEvent && @start == nil
          end

          # extract all sequences to a links
          doc.find("/bm:definitions/bm:process/bm:sequenceFlow").each do |e|
            source = e.attributes['sourceRef']
            target = e.attributes['targetRef']
            cond = e.find('bm:conditionExpression')
            @graph.add_link Link.new(source, target, cond.empty? ? nil : cond.first.text.strip)
          end

          @graph.clean_up do |node|
            if node.type == :scriptTask && (x = @graph.find_script_id(node.id)).any?
              x.each do |k,n|
                n.script = node.script
                n.script_type = node.script_type
              end
              true
            else
              false
            end
          end
        end #}}}

      end

    end


  end

end
