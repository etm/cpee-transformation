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

module CPEE

  module Transformation

    module Container #{{{
      def container?
        @container || false
      end
    end #}}}
    module Struct #{{{
      def each(&a)
        @sub.each{|s| a.call(s)}
      end
      def length
        @sub.length
      end
    end #}}}

    class Node #{{{
      include Container
      @@niceid = {}
      attr_reader :id, :label, :niceid
      attr_reader :endpoints, :methods, :parameters, :attributes
      attr_accessor :script, :script_id, :script_var, :script_type, :incoming, :outgoing, :type
      def initialize(context,id,type,label,incoming,outgoing)
        @@niceid[context] ||= -1
        @niceid = (@@niceid[context] += 1)
        @id = id
        @type = type
        @label = label
        @endpoints = []
        @methods = []
        @script = nil
        @script_type = nil
        @script_id = nil
        @script_var = 'result'
        @parameters = {}
        @incoming = incoming
        @outgoing = outgoing
        @attributes = {}
      end

      def inc_incoming!
        @incoming += 1
      end
      def inc_outgoing!
        @outgoing += 1
      end
    end # }}}
    class Link #{{{
      attr_accessor :from, :to
      attr_reader :condition, :attributes
      def initialize(from,to,cond=nil)
        @from  = from
        @to = to
        @condition = cond
        @attributes = {}
      end
    end #}}}
    class Break < Node #{{{
      def initialize(context)
        super context, '-1', :break, 'BREAK', 1, []
      end
    end #}}}

    class Alternative < Array #{{{
      include Container
      attr_accessor :condition, :condition_type
      attr_reader :id, :attributes
      def condition?; true; end
      def initialize(id)
        @container = true
        @id = id
        @condition = []
        @condition_type = nil
        @attributes = {}
      end
    end #}}}
    class Branch < Array #{{{
      include Container
      attr_reader :id
      def condition?; false; end
      def initialize(id)
        @container = true
        @id = id
      end
    end #}}}

    class Loop #{{{
      include Container
      include Struct
      include Enumerable
      attr_reader :id, :sub, :mode
      attr_accessor :type, :condition, :condition_type
      attr_reader :attributes
      def condition?; true; end
      def initialize(id)
        @container = true
        @id = id
        @type = :loop
        @mode = :exclusive
        @condition = []
        @sub = []
        @condition_type = nil
        @attributes = {}
      end
      def new_branch
        (@sub << Alternative.new(@id)).last
      end
    end #}}}

    class Parallel #{{{
      include Container
      include Struct
      include Enumerable
      attr_reader :id, :sub
      attr_accessor :type, :wait, :cancel
      def initialize(id,type,wait='-1',cancel='last')
        @container = true
        @id = id
        @type = type
        @sub = []
        @wait = wait
        @cancel = cancel
      end
      def new_branch
        (@sub << Branch.new(@id)).last
      end
    end #}}}

    class Conditional #{{{
      include Container
      include Struct
      include Enumerable
      attr_reader :container
      attr_reader :id, :sub, :mode
      attr_reader :attributes
      attr_accessor :type
      def initialize(id,mode,type)
        @container = true
        @id = id
        @sub = []
        @mode = mode
        @type = type
        @attributes = {}
      end
      def new_branch
        (@sub << Alternative.new(@id)).last
      end
    end #}}}

    class Graph #{{{
      attr_reader :flow, :nodes

      def find_node(niceid)
        @nodes.find{|k,v| v.niceid == niceid }
      end

      def initialize
        @nodes = {}
        @links = []
      end

      def clean_up(&bl)
        selnodes = []
        @nodes.each do |k,n|
          ret = bl.call(n)
          selnodes << n if ret
        end
        selnodes.each do |n|
          if n.incoming > 1 || n.outgoing > 1
            raise "#{n.inspect} - not a simple node to remove"
          end
          to,from = nil
          @links.each do |f|
            to = f if f.to == n.id
            from = f if f.from == n.id
          end
          if to && from
            to.to = from.to
            @links.delete(from)
            @nodes.delete(n.id)
          else
            raise "#{n.inspect} - could not remove flow"
          end
        end
      end

      def find_script_id(s)
        @nodes.find_all{|k,n| n.script_id == s}
      end

      def add_node(n,ntype=nil)
        if @nodes.include?(n.id)
          case ntype
            when :outgoing
              @nodes[n.id].inc_outgoing!
            when :incoming
              @nodes[n.id].inc_incoming!
          end
          @nodes[n.id]
        else
          @nodes[n.id] = n
        end
      end

      def link(f,t)
        @links.find{ |x| x.from == f && x.to == t }
      end

      def add_link(l)
        @links << l
      end

      def next_nodes(from)
        links = @links.find_all { |x| x.from == from.id }
        links.map{|x| @nodes[x.to] }
      end

      def next_node(from)
        if (nodes = next_nodes(from)).length == 1
          nodes.first
        else
          raise "#{from.inspect} - multiple outgoing connections"
        end
      end
    end #}}}

      class Tree < Array #{{{
        def condition?; false; end

        def to_s(verbose=true)
          "TREE:\n" << print_tree(self,'  ',verbose)
        end

        def print_tree(ele,indent='  ',verbose=true)
          ret = ''
          ele.each_with_index do |e,i|
            last  = (i == ele.length - 1)
            pchar = last ? '└' : '├'
            if e.container?
              ret << indent + pchar + ' ' + e.class.to_s.gsub(/[^:]*::/,'') + "\n"
              ret << print_tree(e,indent + (last ? '  ' : '│ '),verbose)
            elsif e.is_a?(Break)
              ret << indent + pchar + ' ' + e.class.to_s.gsub(/[^:]*::/,'') + "\n"
            else
              ret << indent + pchar + ' ' + e.niceid.to_s + (verbose ? " (#{e.label})" : "") + "\n"
            end
          end
          ret
        end
        private :print_tree
      end #}}}

      class Traces < Array #{{{
        def initialize_copy(other)
         super
         self.map!{ |t| t.dup }
        end

        def remove(trcs)
          trcs.each do |t|
            self.delete(t)
          end
        end
        def remove_by_endnode(enode)
          self.delete_if do |t|
            t[0] != enode
          end
        end

        def empty!
          self.delete_if{true}
        end

        def remove_empty
          self.delete_if{|t| t.empty? }
        end

        def first_node
          self.first.first
        end
        def second_nodes
          self.map { |t| t.length > 1 ? t[1] : t[0] }
        end

        def shortest
          self.min_by{|e|e.length}
        end

        def legend
          ret = "Legend:\n"
          a = self.flatten.uniq
          a.each {|n| ret << "  " +  n.niceid.to_s + ' ' + n.type.to_s + ' ' + n.label.to_s + "\n" }
          ret
        end

        def to_s
          "TRACES: " + self.collect { |t| t.empty? ? '∅' : t.collect{|n| "%2d" % n.niceid }.join('→ ') }.join("\n        ")
        end

        def shift_all
          self.each{ |tr| tr.shift }
        end
        def pop_all(what=nil)
          if node.nil?
            self.each{ |tr| tr.pop }
          else
            self.each{ |tr| tr.pop if tr.last == what }
          end
        end

        def finished?
          self.reduce(0){|sum,t| sum += t.length} == 0
        end

        def same_first
          (n = self.map{|t| t.first }.uniq).length == 1 ? n.first : nil
        end

        def incoming(node)
          tcount = 1
          self.each do |t|
            break if t.length == 1
            tcount += 1 if t.last == node
          end
          tcount
        end

        def include_in_all?(e)
          num = 0
          self.each{|n| num += 1 if n.include?(e)}
          num == self.length
        end

        def all_loops?
          num = 0
          self.each{|n| num += 1 if n.first == n.last }
          num == self.length
        end

        def add_breaks(context,front=true)
          trueloops = self.find_all{ |t| t.last == t.first }.length
          tb = Break.new(context)
          if trueloops == self.length
            self << (front ? [nil,tb] : [tb,nil])
          else
            self.each do |t|
              t << tb unless t.last == t.first ### an explicit break
            end
          end
        end

        def loops
          lo = Traces.new self.find_all{ |t| t.first == t.last }
          self.each do |t|
            lo << t if lo.second_nodes.include?(t[1])
          end
          lo.uniq!
        end

        def eliminate(loops)
          ### find nested loops
          self.each_with_index do |t,i|
            maxcut = 0
            ### find out which common parts the traces share with theloops
            loops.each do |l|
              maxcut.upto(l.length) do |i|
                maxcut = i if t[0...i] == l[0...i]
              end
            end
            ### in case of nested loop (common part occurs at end of loop), include the whole
            0.upto (maxcut-1) do |j|
              if self[i][j] == self[i].last
                loops << self[i].shift(self[i].length)
              end
            end
          end
          loops.uniq!
          loops.remove_empty
          self.remove_empty

          ### cut from non-nested loops
          self.each_with_index do |t,i|
            maxcut = 0
            ### find out which common parts the traces share with theloops
            loops.each do |l|
              maxcut.upto(l.length) do |i|
                maxcut = i if t[0...i] == l[0...i]
              end
            end
            cutted = self[i].shift(maxcut)
            loops << cutted if cutted.length > 1 ### if only the loop node is left, no need to attach
          end
        end

        def extend
          # find largest common
          max = []
          sh = self.shortest
          sh = sh[0..-2] if sh.first == sh.last
          sh.each_with_index do |e,i|
            max << e if self.include_in_all?(e)
          end
          max = max.last

          # if last is the largest common do nothing
          # else append from last to largest common
          self.each do |t|
            unless t.last == max
              last = t.last
              if t.index(last) && t.index(max)
                (t.index(last) + 1).upto(t.index(max)) do |i|
                  t << t[i]
                end
              end
            end
          end

          max
        end

        def find_endnode
          # supress loops
          trcs = self.dup
          # dangerous TODO
          trcs.delete_if { |t| t.uniq.length < t.length }

          # find common node (except loops)
          enode = nil
          unless trcs.empty?
            trcs.first.each do |n|
              if trcs.include_in_all?(n)
                enode = n
                break
              end
            end
          end
          enode
        end

        def segment_by(endnode)
          # cut shit until common node, return the shit you cut away
          tracesgroup = self.group_by{|t| t.first}.map do |k,trace|
            coltrace = trace.map do |t|
              # slice upto common node, collect the sliced away part
              len = t.index(endnode)
              if len
                cut = t.slice!(0...len)
                cut << t.first
              else # if endnode is nil, then return the whole
                t
              end
            end.uniq
            Traces.new(coltrace)
          end
          [tracesgroup,endnode]
        end
      end #}}}

  end

end
