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

      class Graphviz
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

				def map_nodes(shape,label)
					case [shape,label]
            when ['rectangle',nil];    :task
            when ['diamond','AND'];    :parallelGateway
            when ['diamond','and'];    :parallelGateway
            when ['diamond','X'];      :exclusiveGateway
            when ['diamond','x'];      :exclusiveGateway
            when ['diamond','*'];      :eventBasedGateway
            when ['diamond','o'];      :inclusiveGateway
            when ['circle',''];        :startEvent
            when ['circle',nil];       :startEvent
            when ['doublecircle',''];  :endEvent
            when ['doublecircle',nil]; :endEvent
						else
							nil
					end
				end
				private :map_nodes

        def extract_nodelink(text) #{{{
          text.each_line do |line|
            if line =~ /^\s*"([^"]+)"\[shape=([a-z]+)(\slabel="([^"]*)")?\]\s*;?/
              id = $1
              type = map_nodes($2,$4)
              label = id

              label.sub(/^'/,'')
              label.sub(/'$/,'')
              label.sub(/^"/,'')
              label.sub(/"$/,'')

              n = Node.new(0,id,type,label,0,1)
              @graph.add_node n

							@start = n if n.type == :startEvent && @start == nil
            end
          end
          text.each_line do |line|
            if line =~ /^\s*"([^"]+)"\s+->\s+"([^"]+)"(\s*\[(label="([^"]*)")?\])?\s*;?/
              lid = $1
              rid = $2
              cond = $5

							@graph.add_link Link.new(lid, rid, cond.nil? ? nil : cond)
            end
          end
        end #}}}

      end

    end


  end

end
