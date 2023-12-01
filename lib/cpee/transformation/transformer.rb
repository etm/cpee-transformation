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
# along with cpee-transformation (file COPYING in the main directory). If not,
# see <http://www.gnu.org/licenses/>.

require_relative 'structures'
require 'rubygems'
require 'highline'

module CPEE

  module Transformation

    class Transformer
      def initialize(source)
        @hl = HighLine.new
        @source = source
      end

      def build_traces #{{{
        build_extraces @source.traces, @source.start
        @source.traces
      end #}}}
      def build_tree(debug=false) #{{{
        build_ttree @source.tree, @source.traces.dup, nil, debug
        debug_print debug, 'Tree finished'
        @source.tree
      end #}}}

      def  build_extraces(traces, node) #{{{
        dupt = traces.last.dup
        @source.graph.next_nodes(node).each_with_index do |n,i|
          traces << dupt.dup if i > 0
          if traces.last.include?(n)
            traces.last << n
          else
            traces.last << n
            build_extraces(traces,n)
          end
        end
      end #}}}
      private :build_extraces

      def map_node(node,flat) #{{{
        case node.type
          when :parallelGateway
            flat ? nil : Parallel.new(node.id,node.type)
          when :exclusiveGateway
            flat ? nil : Conditional.new(node.id,:exclusive,node.type)
          when :eventBasedGateway
            flat ? nil : Parallel.new(node.id,node.type,1)
          when :inclusiveGateway
            flat ? nil : Conditional.new(node.id,:inclusive,node.type)
          when :endEvent, :startEvent, nil
            nil
          else
            node
        end
      end #}}}
      private :map_node

      def print_node(niceid)
        @source.graph.find_node(niceid)
      end

      def build_ttree(branch,traces,enode=nil,debug=false,down=0)
        while not traces.finished?
          ### if traces exist more than once, make it so they exist only once
          ### if somebody creates a modell with an inclusive/exclusive that
          ### has identical branches with different conditions, we are fucked
          ### but how are the odds? right? right?
          traces.uniq!
          puts '--> now on ' + down.to_s if debug
          debug_print debug, traces
          if node = traces.same_first
            if branch.empty? && branch.respond_to?(:id)
              li = if (branch.id == traces.first_node.id)
                ### for tail controlled loops, use the link from this to next
                ### if a tasks loops to itself, then second_nodes returns the first
                @source.graph.link(branch.id,traces.second_nodes.first.id)
              else
                if traces.all_tail? && traces.length > 1 && !traces.all_loops?
                  @source.graph.link(traces.first[-2].id,traces.first[-1].id)
                else
                  @source.graph.link(branch.id,traces.first_node.id)
                end
              end
              unless li.nil?
                if branch.condition?
                  branch.condition << li.condition unless li.condition.nil?
                  branch.condition.uniq!
                  branch.condition_type = "text/javascript"
                end
                if branch.respond_to?(:attributes)
                  branch.attributes.merge!(li.attributes)
                  li.attributes.delete_if{true}
                end
              end
            end
            if node == enode
              traces.shift_all
            elsif traces.incoming(node) == 1
              traces.shift_all
              n = map_node(node,traces.same_first)
              if !n.nil? && !(n.container? && traces.finished?)
                (branch << n).compact!
              end
            else
              if node.type == :exclusiveGateway && traces.all_loops? && traces.all_front?
                loops = traces.loops_only
                traces.remove(loops)

                ### an infinite loop that can only be left by break is created
                ### at the output time it is decided wether this can be optimized
                branch << Loop.new(node.id)
                branch.last.mode = :post_test if loops.all_tail?
                ### remove the exclusive gateway because we no longer need it
                ### if there is non (tail controlled, remove the loop target (last)
                if node.type == :exclusiveGateway
                  loops.shift_all
                  traces.shift_all
                else
                  loops.pop_all
                end
                ### add the blank conditional to get a break
                puts '--> down head_loop to ' + (down + 1).to_s if debug
                if loops.same_first
                  build_ttree branch.last.new_branch, loops, nil, debug, down + 1
                else
                  build_ttree branch, loops, nil, debug, down + 1
                end
                puts '--> up head_loop from ' + (down + 1).to_s if debug
              elsif node.type == :exclusiveGateway && !traces.all_loops? && traces.all_front?
                loops = traces.loops_only
                traces.remove(loops)
                traces.eliminate_front(loops)
                build_ttree branch, loops, nil, debug, down + 1
              elsif node.type == :exclusiveGateway && !traces.all_loops? && !traces.all_front?
                loops = traces.loops_and_partial_loops
                traces.remove(loops)

                ### an infinite loop that can only be left by break is created
                ### at the output time it is decided wether this can be optimized
                branch << Loop.new(node.id)
                ### duplicate because we need it later to remove all the shit from traces
                loops.add_breaks(self.object_id,node.type == :exclusiveGateway)
                ### remove the exclusive gateway because we no longer need it
                ### if there is non (tail controlled, remove the loop target (last)
                if node.type == :exclusiveGateway
                  loops.shift_all
                  traces.shift_all
                else
                  loops.pop_all
                end
                ### add the blank conditional to get a break
                puts '--> down head_loop to ' + (down + 1).to_s if debug
                if loops.same_first
                  build_ttree branch.last.new_branch, loops, nil, debug, down + 1
                else
                  build_ttree branch, loops, nil, debug, down + 1
                end
                puts '--> up head_loop from ' + (down + 1).to_s if debug
              else
                loops = traces.loops_and_partial_loops

                ### throw away the loop traces, remove loop traces from front of all other traces
                traces.remove(loops)
                traces.eliminate(loops)
                loops.extend
                puts '--> down tail_loop to ' + (down + 1).to_s if debug
                build_ttree branch, loops.dup, nil, debug, down + 1
                puts '--> up tail_loop from ' + (down + 1).to_s if debug
              end
              traces.remove_empty
            end
          else
            endnode = traces.find_endnode || enode
            puts "--> endnode #{endnode.nil? ? 'nil' : endnode.niceid}" if debug
            tracesgroup, endnode = traces.segment_by endnode
            tracesgroup.each do |trcs|
              next unless branch.last.respond_to?(:new_branch)
              nb = branch.last.new_branch
              unless trcs.finished?
                puts '--> branch down to ' + (down + 1).to_s if debug
                build_ttree nb, trcs, endnode, debug, down + 1
                puts '--> branch up from ' + (down + 1).to_s if debug
              end
            end
            # remove all traces that don't start with endnode to account for loops
            if endnode.nil?
              traces.empty!
            else
              traces.remove_by_endnode(endnode)
            end
          end
        end
      end
      private :build_ttree

      def debug_print(debug,traces) #{{{
        if debug
          puts '-' * @hl.output_cols, @source.tree.to_s
          puts traces.to_s
          @hl.ask('Continue ... '){ |q| q.echo = false }
        end
      end #}}}
      private :debug_print

      def generate_model(formater) #{{{
        formater.new(@source.tree).generate
      end #}}}

    end

  end

end
