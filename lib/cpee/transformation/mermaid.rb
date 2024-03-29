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
          Node.class_variable_set(:@@niceid,  {})

          @tree = Tree.new
          @start = nil

          @dataelements = {}
          @endpoints = {}
          @graph = Graph.new

          extract_nodelink(text)

          @traces = Traces.new [[@start]]
        end #}}}

				def map_nodes(node)
					case node
            when 'task'; :task
            when 'parallelgateway';   :parallelGateway
            when 'exclusivegateway';  :exclusiveGateway
            when 'eventbasedgateway'; :eventBasedGateway
            when 'inclusivegateway';  :inclusiveGateway
            when 'endevent';          :endEvent
            when 'startevent';        :startEvent
						else
							nil
					end
				end
				private :map_nodes

        def extract_nodelink(text) #{{{
          first = nil
          text.each_line do |line|
            if line =~ /-->/
              a = line.strip.split(/-->\s*(\|([^|]+)\|)?/)
              if a.length == 2
                l, r = a
              else
                l, _, c, r = a
              end

              lid, ltype, llabel = l.strip.split(':',3)
              rid, rtype, rlabel = r.strip.split(':',3)

              ltype = 'task' if ltype.nil?
              rtype = 'task' if rtype.nil?

              if lid =~ /^([a-zA-Z])+(\[([^\]]+)\])?/
                lid = $1
                llabel = $3
              else
                lid = lid.to_i.to_s
              end

              if rid =~ /^([a-zA-Z])+(\[([^\]]+)\])?/
                rid = $1
                rlabel = $3
              else
                rid = rid.to_i.to_s
              end

              llabel = '' if llabel.nil?
              rlabel = '' if rlabel.nil?
              llabel.sub(/^'/,'')
              llabel.sub(/'$/,'')
              llabel.sub(/^"/,'')
              llabel.sub(/"$/,'')
              rlabel.sub(/^'/,'')
              rlabel.sub(/'$/,'')
              rlabel.sub(/^"/,'')
              rlabel.sub(/"$/,'')

							# every line contains a link
							@graph.add_link Link.new(lid, rid, c.nil? ? nil : c.to_s)

              n1 = Node.new(0,lid,map_nodes(ltype),llabel.sub(/^\(/,'').sub(/\)$/,''),0,1)
              n2 = Node.new(0,rid,map_nodes(rtype),rlabel.sub(/^\(/,'').sub(/\)$/,''),1,0)

              @graph.add_node n1, :outgoing
              @graph.add_node n2, :incoming

						  first = n1 if first.nil?
              @start = n1 if n1.type == :startEvent && @start.nil?
            end
            @start = first if @start.nil?
          end
        end #}}}

      end

    end


  end

end
