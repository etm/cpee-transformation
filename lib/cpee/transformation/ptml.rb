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

require_relative 'target'
require 'xml/smart'

module CPEE

  module Transformation

    module Source #{{{

      class PTML
        attr_reader :tree, :start, :dataelements, :endpoints, :graph, :traces

        def initialize(xml) #{{{
          Node.class_variable_set(:@@niceid,  {})

          @tree = Tree.new
          @start = nil

          doc = XML::Smart.string(xml)

          @graph = Graph.new
          extract_nodelink(doc)

          if @start.nil?
            @traces = Traces.new [[]]
          else
            @traces = Traces.new [[@start]]
          end
        end #}}}

        def map_nodes(node) #{{{
          case node
            when :sequence; :sequence
            when :manualTask; :task
            when :automaticTask; :task
            when :and;   :parallelGateway
            when :xor;  :exclusiveGateway
            when :xorLoop;  :exclusiveGateway
            #when :eventbasedgateway; :eventBasedGateway
            when :or;  :inclusiveGateway
            #when 'endevent';          :endEvent
            #when 'startevent';        :startEvent
            else
              nil
          end
        end
        private :map_nodes  #}}}

        def iterate_ptml(sid,doc) #{{{
          # get node and get type
          se = doc.find("//processTree/*[@id='#{sid}']").first
          stype = map_nodes(se.qname.name.to_sym)
          print '============current', ' ', sid, ' ', @last,' ', stype, ';'
          pp ' '
          if stype == :sequence
            #get al outgoing elements
            outgoings = doc.find("//parentsNode[@sourceId='#{sid}']")
            outgoings.each_with_index do |e, i|
              iterate_ptml(e.attributes['targetId'],doc)
            end
          elsif stype == :exclusiveGateway || stype == :parallelGateway || stype == :inclusiveGateway
            outgoings = doc.find("//parentsNode[@sourceId='#{sid}']")
            if @graph.nodes.length == 0   #if first element
              n = Node.new(self.object_id,sid,stype,"",1,outgoings.length)
              @start = n
            else
              n = Node.new(self.object_id,sid,stype,"",0,outgoings.length)
              @graph.add_link Link.new(@last, sid, nil)
            end
            @graph.add_node n
            print '***********test    ', @last, " ", sid
            pp ' '
            @last = sid
            final = []
            outgoings.each_with_index do |e, i|
              iterate_ptml(e.attributes['targetId'],doc)
              final << @last
              @last = sid
            end
            pp final
            rid = rand.to_s[2..11]
            n = Node.new(self.object_id,rid,stype,"",outgoings.length,1)
            @graph.add_node n
            final.each do |f|
              @graph.add_link Link.new(f, rid, nil)
            end
            @last = rid
          elsif stype == :task
            pp se.attributes['name']
            # write node
            if @graph.nodes.length == 0   #if first element
              n = Node.new(self.object_id,sid,stype,se.attributes['name'],0,1)
              @start = n
            else                          #other elements
              n = Node.new(self.object_id,sid,stype,se.attributes['name'],1,1)
              @graph.add_link Link.new(@last, sid, nil)
            end
            @graph.add_node n
            @last = sid
          end
          #@last = sid
        end
        private :iterate_ptml
        #}}}

        def extract_nodelink(doc) #{{{
          #extract nodes
          sid = doc.find("//processTree/@root").first.value
          @last = 0
          iterate_ptml(sid,doc)
          pp @last
          pp @graph
        end #}}}

      end

    end #}}}

    module Target #{{{

      class PTML < Default

        def generate
          start_id = "rootid"
          @last = start_id
          res = XML::Smart.string("<ptml><processTree id='tree01' name='ptml-tree' root='#{start_id}'/></ptml>")
          pp "start"
          generate_in_list(@tree,res.root.children[0])
          res.to_s
        end

        private

          def set_edges(source,target,res)
            rid = rand.to_s[2..11]
            res.add('parentsNode','id'=> rid, 'sourceId' => source, 'targetId' => target)
            res
          end

          def print_Break(node,res)
            pp node
          end

          def print_Loop(node,res)
            original_last = @last
            nid = "a#{node.id}"
            res.add('xorLoop','id' => nid, 'name' => nil)
            set_edges(@last,nid,res)
            @last = nid

            if node.sub.length == 2
              node.sub.reverse.each do |branch|
                if branch[0].type == :break
                  rid = rand.to_s[2..11]
                  res.add('automaticTask', 'id' => rid, 'name' => 'tau')
                  set_edges(@last,rid,res)
                elsif branch.length == 1
                  generate_in_list(branch,res)
                elsif branch.length >1
                  branch_last = @last
                  rid = rand.to_s[2..11]
                  res.add('sequence', 'id' => rid, 'name' => 'just-sequence')
                  set_edges(@last,rid,res)
                  @last = rid
                  generate_in_list(branch,res)
                  @last = branch_last
                end
              end
            elsif node.sub.length > 2
              node.sub.reverse.each do |branch|
                if branch[0].type == :break
                  rid = rand.to_s[2..11]
                  res.add('automaticTask', 'id' => rid, 'name' => 'tau')
                  set_edges(@last,rid,res)
                  #Add new xor
                  xor_id = rand.to_s[2..11]
                  res.add('xor', 'id' => xor_id, 'name' => 'help-xor')
                  set_edges(@last,xor_id,res)
                  escape_id = rand.to_s[2..11]
                  res.add('manualTask', 'id' => escape_id, 'name' => 'escape')
                  set_edges(xor_id,escape_id,res)
                  @last = xor_id
                else
                  if branch.length == 1
                    generate_in_list(branch,res)
                  elsif branch.length >1
                    branch_last = @last
                    rid = rand.to_s[2..11]
                    res.add('sequence', 'id' => rid, 'name' => 'just-sequence')
                    set_edges(@last,rid,res)
                    @last = rid
                    generate_in_list(branch,res)
                    @last = branch_last
                  end
                end
              end
            end
            @last = original_last
            res
          end

          def print_Node(node,res) #{{{
            #if the first element in the process models is task
            if res.children.length == 0
              res.add('sequence', 'id' => @last, 'name' => 'main-sequence')
            end
            nid = "a#{node.niceid}"
            if node.endpoints.empty? && ((!node.script.nil? && node.script.strip != '') || node.type == :scriptTask)
              n = res.add('automaticTask','id' => nid, 'name' => node.label)
            else
              n = res.add('manualTask', 'id' => nid, 'name' => node.label)
            end
            set_edges(@last,nid,res)
            res
          end #}}}

          def print_Parallel(node,res) #{{{
            print_Conditional(node,res)
            res
          end #}}}

          def print_Inclusive(node,res) #{{{
            print_Conditional(node,res)
            res
          end #}}}

           def print_Conditional(node,res) #{{{
            original_last = @last
            nid = "a#{node.id}"
            if node.type == :exclusiveGateway
              res.add('xor','id' => nid, 'name' => nil)
            elsif node.type == :parallelGateway
              res.add('and','id' => nid, 'name' => nil)
            elsif node.type == :inclusiveGateway
              res.add('or','id' => nid, 'name' => nil)
            end
            set_edges(@last,nid,res)
            @last = nid
            node.sub.each do |branch|
              pp branch.condition.any?
              pp branch.condition
              if branch.length == 0
                rid = rand.to_s[2..11]
                res.add('automaticTask', 'id' => rid, 'name' => 'tau')
                set_edges(@last,rid,res)
              elsif branch.length == 1
                generate_in_list(branch,res)
              elsif branch.length >1
                branch_last = @last
                rid = rand.to_s[2..11]
                res.add('sequence', 'id' => rid, 'name' => 'just-sequence')
                set_edges(@last,rid,res)
                @last = rid
                generate_in_list(branch,res)
                @last = branch_last
              end
            end
            @last = original_last
            res
          end #}}}

      end

    end #}}}

  end

end
