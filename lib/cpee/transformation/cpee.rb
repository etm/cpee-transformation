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

require_relative 'target'
require 'xml/smart'

module CPEE

  module Transformation

    module Source #{{{

      class CPEE
        attr_reader :tree, :start, :dataelements, :endpoints, :graph, :traces

         def initialize(text)
          @tree = Tree.new
          @start = nil

          @dataelements = {}
          @endpoints = {}
          @graph = Graph.new

          extract_original(text)

          if @start.nil?
            @traces = Traces.new [[]]
          else
            @traces = Traces.new [[@start]]
          end
        end

        def dive(node,n1=nil,condition=nil,otherwise=false)
          if node.children.empty?
            return n1
          end
          if n1.nil?
            n1 = @start = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:startEvent,'',0,1)
          end
          node.children.each do |ele|
            case ele.qname.name
              when 'loop'
                if ele.attributes['mode'] == 'pre_test'
                  nx = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:exclusiveGateway,nil,2,2)
                  @graph.add_link Link.new(n1.id, nx.id, condition, otherwise)
                  condition = nil
                  @graph.add_node nx
                  n1 = nx

                  bn = dive ele, nx, ele.attributes['condition']

                  @graph.add_link Link.new(bn.id, nx.id)
                else
                  nx = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:exclusiveGateway,nil,2,1)
                  @graph.add_link Link.new(n1.id, nx.id, condition, otherwise)
                  condition = nil
                  @graph.add_node nx

                  bn = dive ele, nx, ele.attributes['condition']

                  no = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:exclusiveGateway,nil,1,2)
                  @graph.add_link Link.new(bn.id, no.id)
                  @graph.add_node no
                  n1 = no

                  @graph.add_link Link.new(no.id, nx.id, ele.attributes['condition'])
                end
              when 'call'
                no = Node.new(0,ele.attributes['id'],:task,ele.find("string(d:parameters/d:label)"),1,1)
                no.methods << ele.find("string(d:parameters/d:method)")
                no.endpoints << ele.attributes['endpoint']
                ele.find("d:parameters/d:arguments/d:*").each do |e|
                  no.arguments[e.qname.name] = e.text
                end
                if (sc = ele.find("d:code/d:finalize")).any?
                  no.script_type = 'application/x-ruby'
                  no.script = sc.first.text
                end
                @graph.add_link Link.new(n1.id, no.id, condition, otherwise)
                condition = nil
                @graph.add_node no
                n1 = no
              when 'manipulate'
                no = Node.new(0,ele.attributes['id'],:scriptTask,ele.attributes['label'].to_s,1,1)
                no.script = ele.text
                no.script_type = 'application/x-ruby'
                @graph.add_link Link.new(n1.id, no.id, condition, otherwise)
                condition = nil
                @graph.add_node no
                n1 = no
              when 'parallel'
                bra = ele.find('d:parallel_branch')
                ns = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:parallelGateway,nil,1,bra.length)
                ns.attributes[:wait] = ele.attributes['wait'] || -1
                ns.attributes[:cancel] = ele.attributes['cancel'] || 'last'
                @graph.add_link Link.new(n1.id, ns.id, condition, otherwise)
                condition = nil
                ne = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:parallelGateway,nil,1,bra.length)
                @graph.add_node ns
                @graph.add_node ne
                bra.each do |br|
                  bn = dive br, ns
                  @graph.add_link Link.new(bn.id, ne.id)
                end
                n1 = ne
              when 'choose'
                bra = ele.find('d:alternative|d:otherwise')
                ns = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:exclusiveGateway,nil,1,bra.length)
                @graph.add_link Link.new(n1.id, ns.id, condition, otherwise)
                condition = nil
                ne = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:exclusiveGateway,nil,1,bra.length)
                @graph.add_node ns
                @graph.add_node ne
                bra.each do |br|
                  bn = dive br, ns, br.attributes['condition'], br.qname.name == 'otherwise'
                  if bn == ns
                    @graph.add_link Link.new(bn.id, ne.id, br.attributes['condition'], br.qname.name == 'otherwise')
                  else
                    @graph.add_link Link.new(bn.id, ne.id)
                  end
                end
                n1 = ne
              when 'break'
                no = Node.new(0,ele.attributes['id'],:break,'',1,1)
                @graph.add_link Link.new(n1.id, no.id, condition, otherwise)
                @graph.add_node no
                condition = nil
                n1 = no
            end
          end
          n1
        end
        private :dive

        def extract_original(text)
          doc = XML::Smart::string(text)
          doc.register_namespace :d, 'http://cpee.org/ns/description/1.0'
          bn = dive doc.root
          ne = Node.new(0,Digest::MD5.hexdigest(Kernel::rand().to_s),:endEvent,'',1,0)
          @graph.add_node ne
          @graph.add_link Link.new(bn.id, ne.id, nil)
        end

      end

    end #}}}

    module Target #{{{

      class CPEE < Default

        def generate
          res = XML::Smart.string("<description xmlns='http://cpee.org/ns/description/1.0' xmlns:a='http://cpee.org/ns/annotation/1.0'/>")
          res.register_namespace 'd', 'http://cpee.org/ns/description/1.0'
          res.register_namespace 'a', 'http://cpee.org/ns/annotation/1.0'
          generate_for_list(@tree,res.root)
          res.to_s
        end

        private
          def print_Break(node,res)
            res.add('escape', 'a:alt_id' => node.id)
          end

          def print_Loop(node,res)
            if node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0)
              s1 = res.add('loop', 'mode' => node.mode, 'condition' => node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && '), 'a:alt_id' => node.id)
              s1.attributes['language'] = node.sub[0].condition_type unless node.sub[0].condition_type.nil?
              node.sub[0].attributes.each do |k,v|
                s1.attributes[k] = v
              end
              generate_for_list(node.sub[0],s1)
            else
              s1 = res.add('loop', 'mode' => node.mode, 'condition' => node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && '))
              if node.sub.length == 1
                generate_for_list(node.sub[0],s1)
              else
                print_Conditional(node,s1)
              end
            end
            s1
          end

          def print_Node(node,res)
            nid = "a#{node.niceid}"
            if node.endpoints.empty? && ((!node.script.nil? && node.script.strip != '') || node.type == :scriptTask)
              n = res.add('d:manipulate', node.script, 'id' => nid, 'a:alt_id' => node.id)
              n.attributes['label'] = node.label.gsub(/"/,"\\\"")
              n.attributes['output'] = node.script_var unless node.script_var.nil?
              n.attributes['language'] = node.script_type unless node.script_type.nil?
            else
              n   = res.add('d:call', 'id' => nid, 'endpoint' => node.endpoints.join(','), 'a:alt_id' => node.id)
              p   = n.add('d:parameters')
                    p.add('d:label',"#{node.label}")
                    p.add('d:method',node.methods.join(',') || 'post')
                    p.add('d:type',":#{node.type}")
              par = p.add('d:arguments')
              node.arguments.each do |k,v|
                par.add(k,v)
              end
              if !node.script.nil? && ((node.script.is_a?(String) && node.script.strip != '') ||  node.script.is_a?(Hash))
                y = n.add('d:code')
                if node.script.is_a?(String)
                  x = y.add('d:finalize',node.script)
                  x.attributes['output'] = node.script_var unless node.script_var.nil?
                  x.attributes['language'] = node.script_type unless node.script_type.nil?
                else
                  node.script.each do |k,v|
                    x = y.add('d:' + k,v)
                    x.attributes['output'] = node.script_var unless node.script_var.nil?
                    x.attributes['language'] = node.script_type unless node.script_type.nil?
                  end
                end
              end
            end
          end

          def print_Parallel(node,res)
            s1 = res.add('parallel','wait' => node.wait, 'cancel' => node.cancel, 'a:alt_id' => node.id)
            node.sub.each do |branch|
              s2 = s1.add('parallel_branch')
              generate_for_list(branch,s2)
            end
            s1
          end

          def print_Conditional(node,res)
            s1 = res.add('d:choose', 'mode' => node.mode == :inclusive ? 'inclusive' : 'exclusive', 'a:alt_id' => node.id)
            node.sub.each do |branch|
              s2 = if branch.condition.any?
                a = s1.add('d:alternative','condition' => branch.condition.join(' or '))
                a.attributes['language'] = branch.condition_type unless branch.condition_type.nil?
                a
              else
                if branch.otherwise
                  s1.add('d:otherwise')
                else
                  s1.add('d:alternative', 'condition' => '')
                end
              end
              branch.attributes.each do |k,v|
                s2.attributes[k] = v
              end
              generate_for_list(branch,s2)
            end
            if (x = s1.find('d:otherwise')).any?
              s1.add x
            end
            s1
          end

      end

    end #}}}

  end

end
