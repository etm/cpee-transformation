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

require_relative 'target'
require 'xml/smart'

module CPEE

  module Transformation

    module Target #{{{

      ### workflow net in the pnml dialect pm4py reads ($invisible$, finalmarkings).
      ### every print_* gets the place it starts from and returns the place it
      ### ends in, nil after break and terminate
      class PNML < Default

        def generate
          @places = []
          @transitions = []
          @arcs = []
          @exits = []
          @start = place(1,'start')
          @end = place(0,'end')
          last = generate_in_list(@tree,silent(@start))
          silent(last,@end) if last
          reduce
          to_xml
        end

        private

          def place(tokens=0,id=nil)
            @places << { :id => id || "p#{@places.length + 1}", :tokens => tokens }
            @places.last
          end

          def transition(name,silent=false)
            @transitions << { :id => "t#{@transitions.length + 1}", :name => name, :silent => silent }
            @transitions.last
          end

          def arc(source,target)
            @arcs << [source,target]
          end

          def step(from,to,name,silent)
            to ||= place
            t = transition(name,silent)
            arc(from,t)
            arc(t,to)
            to
          end

          def silent(from,to=nil,name=nil) = step(from,to,name,true)
          def visible(from,name) = step(from,nil,name,false)

          def script?(node)
            node.endpoints.empty? && ((!node.script.nil? && node.script.strip != '') || node.type == :scriptTask)
          end

          def activity(node,from)
            label = node.label.to_s.strip
            visible(from,label.empty? ? node.id.to_s : label)
          end

          ### after break or terminate nothing is reachable
          def alive(pn) = pn || place

          def print_Node(node,pn) = activity(node,alive(pn))

          def print_Break(node,pn)
            silent(alive(pn),@exits.last || @end,'break')
            nil
          end

          def print_Terminate(node,pn)
            silent(alive(pn),@end,'terminate')
            nil
          end

          def print_Parallel(node,pn)
            ### a place is a deferred choice
            return choice(node.sub,alive(pn)) if node.type == :eventBasedGateway
            split = transition(nil,true)
            join = transition(nil,true)
            arc(alive(pn),split)
            node.sub.each do |branch|
              bp = place
              arc(split,bp)
              last = generate_in_list(branch,bp)
              arc(last,join) if last
            end
            to = place
            arc(join,to)
            to
          end

          ### inclusive: parallel, every branch can be skipped (also all of them)
          def print_Conditional(node,pn)
            return choice(node.sub,alive(pn)) unless node.type == :inclusiveGateway
            split = transition(nil,true)
            join = transition(nil,true)
            arc(alive(pn),split)
            node.sub.each do |branch|
              bp = place
              arc(split,bp)
              last = choice([branch,[]],bp)
              arc(last,join) if last
            end
            to = place
            arc(join,to)
            to
          end

          ### exclusive: all branches start in the same place, conditions are lost
          def choice(branches,pn)
            merge = place
            reached = false
            branches.each do |branch|
              last = generate_in_list(branch,pn)
              next unless last
              silent(last,merge)
              reached = true
            end
            reached ? merge : nil
          end

          ### single: body plus the (implicit) way out, like in the other targets.
          ### otherwise the alternatives decide, and only breaks leave the loop
          def print_Loop(node,pn)
            head = silent(alive(pn))
            exit = place
            @exits.push exit
            single = node.sub.length == 1 || (node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0))
            finite = single && (node.sub.length == 2 || node.sub[0].condition.any?)
            silent(head,exit) if finite && node.mode == :pre_test
            last = single ? generate_in_list(node.sub[0],head) : choice(node.sub,head)
            if last
              silent(last,head) unless last.equal?(head)
              silent(last,exit) if finite && node.mode != :pre_test
            end
            @exits.pop
            exit
          end

          def inputs(n) = @arcs.select { |s,t| t.equal?(n) }
          def outputs(n) = @arcs.select { |s,t| s.equal?(n) }

          ### fuse places connected by a silent transition, if the first place
          ### leads nowhere else. Does not change what the net can do
          def reduce
            loop do
              fused = @transitions.any? do |t|
                next false unless t[:silent]
                ins, outs = inputs(t), outputs(t)
                next false unless ins.length == 1 && outs.length == 1
                p, q = ins[0][0], outs[0][1]
                next false if p.equal?(q) || outputs(p).length != 1
                if inputs(q).length == 1
                  keep, gone = p, q
                  moved = outputs(q).map { |s,x| [keep,x] }
                elsif p[:tokens] == 0
                  keep, gone = q, p
                  moved = inputs(p).map { |x,s| [x,keep] }
                else
                  next false
                end
                next false if moved.any? { |a| @arcs.any? { |b| b[0].equal?(a[0]) && b[1].equal?(a[1]) } }
                @arcs.reject! { |s,x| s.equal?(gone) || x.equal?(gone) || s.equal?(t) || x.equal?(t) }
                @arcs.concat moved
                @transitions.delete_if { |x| x.equal?(t) }
                @places.delete_if { |x| x.equal?(gone) }
                @start = keep if gone.equal?(@start)
                @end = keep if gone.equal?(@end)
                keep[:id] = gone[:id] if %w(start end).include?(gone[:id])
                true
              end
              break unless fused
            end
            @places.select! { |x| x.equal?(@start) || x.equal?(@end) || @arcs.any? { |s,t| s.equal?(x) || t.equal?(x) } }
          end

          def to_xml
            res = XML::Smart.string('<pnml xmlns="http://www.pnml.org/version-2009/grammar/pnml"><net id="net1" type="http://www.pnml.org/version-2009/grammar/pnmlcoremodel"><page id="page1"/></net></pnml>')
            res.register_namespace 'p', 'http://www.pnml.org/version-2009/grammar/pnml'
            net = res.find('/p:pnml/p:net').first
            page = res.find('/p:pnml/p:net/p:page').first
            @places.each do |x|
              n = page.add('place', 'id' => x[:id])
              n.add('name').add('text',x[:id])
              n.add('initialMarking').add('text',x[:tokens].to_s) if x[:tokens] > 0
            end
            @transitions.each do |x|
              n = page.add('transition', 'id' => x[:id])
              n.add('name').add('text',x[:name] || x[:id])
              n.add('toolspecific', 'tool' => 'ProM', 'version' => '6.4', 'activity' => '$invisible$') if x[:silent]
            end
            @arcs.each_with_index do |(s,t),i|
              page.add('arc', 'id' => "a#{i + 1}", 'source' => s[:id], 'target' => t[:id])
            end
            net.add('finalmarkings').add('marking').add('place', 'idref' => @end[:id]).add('text','1')
            res.to_s
          end

      end

      ### calls as in cpee logs: calling, receiving (once or more), done.
      ### scripts only log done. names are <id>_<lifecycle>
      class PNML_with_lifecycle < PNML

        private

          def activity(node,from)
            return visible(from,"#{node.id}_done") if script?(node)
            called = visible(from,"#{node.id}_calling")
            received = visible(called,"#{node.id}_receiving")
            silent(received,called,'redo_receiving')
            visible(received,"#{node.id}_done")
          end

      end

    end #}}}

  end

end
