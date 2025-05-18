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
require 'securerandom'
require 'json'

module CPEE

  module Transformation

    module Source

      class Beautiful
        attr_reader :tree, :start, :dataelements, :endpoints, :graph, :traces

         def initialize(text) #{{{
          Node.class_variable_set(:@@niceid,  {})

          @tree = Tree.new
          @start = nil

          @dataelements = {}
          @endpoints = {}
          @graph = Graph.new

          extract_log(text)

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

        def extract_log(text) #{{{
          first = nil
          decisions = {}
          decisions_join = {}
          loops = []
          loops_end = []
          parallel_joins = []
          @start = Node.new(0,SecureRandom.uuid,:startEvent,'start',0,1)
          @graph.add_node @start
          last = @start
          cond = nil
          text.each_line do |line|
            if line =~ /^\s*beautiful_pipeline_end_check\s-\s(\d+)\s-\s(\d+)/ #{{{
              key = $1
              if decisions[key]
                decisions_join[key] << last
              end
              lid = SecureRandom.uuid
              n1 = Node.new(0,lid,:exclusiveGateway,'xor end',0,0)
              graph.add_node n1
              decisions_join[key].each do |e|
                graph.add_link Link.new(e.id,lid,nil)
              end
              last = n1
              decisions_join.delete(key)
              decisions.delete(key) #}}}
            elsif line =~ /^\s*beautiful_pipeline_check\s-\s(\d+)\s-\s(\d+)/ #{{{
              key = $1
              if decisions[key]
                decisions_join[key] << last
                last = decisions[key]
              else
                lid = SecureRandom.uuid
                n1 = Node.new(0,lid,:exclusiveGateway,'xor otherwise',0,0)
                graph.add_node n1
                graph.add_link Link.new(last.id,lid,nil)
                last = n1
                decisions[key] = n1
                decisions_join[key] = []
              end #}}}
            elsif line =~ /^\s*beautiful_pipeline_check\s-\s(\d+)\s-\s(.*)\s-\s(\d+)/ #{{{
              key = $1
              if decisions[key]
                decisions_join[key] << last
                last = decisions[key]
              else
                lid = SecureRandom.uuid
                cond = $2
                n1 = Node.new(0,lid,:exclusiveGateway,'xor',0,0)
                graph.add_link Link.new(last.id,lid,nil)
                graph.add_node n1
                last = n1
                decisions[key] = n1
                decisions_join[key] = []
              end #}}}
            elsif line =~ /^\s*beautiful_pipeline_loop\s-\s(.*)\s-\s(\d+)/ #{{{
              lid1 = SecureRandom.uuid
              lid2 = SecureRandom.uuid
              cond = $1
              n1 = Node.new(0,lid1,:exclusiveGateway,'loope',0,0)
              n2 = Node.new(0,lid2,:exclusiveGateway,'loops',0,0)
              graph.add_link Link.new(last.id,lid1,nil)
              graph.add_link Link.new(lid1,lid2,nil)
              graph.add_node n1
              graph.add_node n2
              last = n2
              loops << n1
              loops_end << n2 #}}}
            elsif line =~ /^\s*beautiful_pipeline_end_loop\s-\s(\d+)/ #{{{
              graph.add_link Link.new(last.id,loops.last.id,nil)
              last = n1
              loops << n1
              last = loops_end.pop
              loops.pop #}}}
            elsif line =~ /^\s*beautiful_pipeline_continue\s-\s(\d+)/ #{{{
              graph.add_link Link.new(last.id,loops.last.id,nil) #}}}
            elsif line =~ /^\s*beautiful_pipeline_break\s-\s(\d+)/ #{{{
              lid = SecureRandom.uuid
              n1 = Node.new(0,lid,:break,'break',0,0)
              graph.add_node n1
              graph.add_link Link.new(last.id,lid,nil)
              last = n1 #}}}
            elsif line =~ /^\s*beautiful_pipeline_parallel\s-\s(\d+)/ #{{{
              lid = SecureRandom.uuid
              n1 = Node.new(0,lid,:parallelGateway,'parallel_start',0,0)
              parallel_joins << [ n1, {} ]
              last = n1 #}}}
            elsif line =~ /^\s*beautiful_pipeline_end_parallel\s-\s(\d+)/ #{{{
              lay = $1
              lid = SecureRandom.uuid
              n1 = Node.new(0,lid,:parallelGateway,'parallel_join',0,0)
              start, list = parallel_joins.pop
              list.each do |e|
                graph.add_link Link.new(e.id,lid,nil)
              end #}}}
            elsif line =~ /^\s*(\{.*\})\s-\s(\d+)/ #{{{
              pj = parallel_joins.last
              pid = $2
              j = JSON::parse($1.gsub(/'/,'"'))
              lid = SecureRandom.uuid
              n1 = Node.new(0,lid,:task,j.dig('name'),0,0)
              graph.add_node n1
              if pj.nil? || pj[1].has_key?(pid)
                graph.add_link Link.new(last.id,lid,cond.nil? ? nil : cond)
              else
                graph.add_link Link.new(pj[0].id,lid,cond.nil? ? nil : cond)
              end
              cond = nil
              last = n1
              pj[1][pid] = n1 if pj
            end #}}}
          end
        end #}}}

      end

    end

  end

end
