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

require_relative 'structures'
require_relative 'target'

module CPEE

  module Transformation

    ### a double quoted dot string, with \" and \\ inside
    GRAPHVIZ_STRING = /"((?:[^"\\]|\\.)*)"/

    module Source #{{{

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

          if @start.nil?
            @traces = Traces.new [[]]
          else
            @traces = Traces.new [[@start]]
          end
        end #}}}

				def map_nodes(shape,label)
					case [shape,label]
            in ['box' | 'rect' | 'rectangle', _];    :task
            in ['component', _];                     :scriptTask
            in ['diamond', 'AND' | 'and' | '+'];     :parallelGateway
            in ['diamond', 'X' | 'x'];               :exclusiveGateway
            in ['diamond', '*'];                     :eventBasedGateway
            in ['diamond', 'o' | 'O'];               :inclusiveGateway
            in ['circle', '' | nil];                 :startEvent
            in ['circle', '^'];                      :break
            in ['circle' | 'doublecircle', 'terminate'];  :terminate
            in ['doublecircle', '' | nil];           :endEvent
						else
							nil
					end
				end
				private :map_nodes

        def unescape(s) #{{{
          s&.gsub(/\\(.)/m) { $1 == 'n' ? "\n" : $1 }
        end #}}}
        private :unescape

        ### key=value or key="value" pairs of an attribute list [...]
        def attributes(text) #{{{
          ret = {}
          text.to_s.scan(/(\w+)\s*=\s*(?:#{GRAPHVIZ_STRING}|([^\s,;\]]+))/) do |k,q,v|
            ret[k] = q.nil? ? v : unescape(q)
          end
          ret
        end #}}}
        private :attributes

        def extract_nodelink(text) #{{{
          first = nil
          links = []
          text.each_line do |line|
            if line =~ /^\s*#{GRAPHVIZ_STRING}\s*->\s*#{GRAPHVIZ_STRING}\s*(\[(.*)\])?\s*;?\s*$/
              links << [unescape($1), unescape($2), attributes($4)['label']]
            elsif line =~ /^\s*#{GRAPHVIZ_STRING}\s*\[(.*)\]\s*;?\s*$/
              id = unescape($1)
              attrs = attributes($2)
              type = map_nodes(attrs['shape'],attrs['label'])
              ### without a label graphviz shows the id
              label = attrs['label'] || id

              n = Node.new(self.object_id,id,type,label,0,0)
              @graph.add_node n

              first = n if first.nil?
							@start = n if n.type == :startEvent && @start.nil?
            end
          end
          links.each do |lid, rid, cond|
            @graph.add_link Link.new(lid, rid, cond)
            @graph.nodes[lid]&.inc_outgoing!
            @graph.nodes[rid]&.inc_incoming!
          end
          @start = first if @start.nil?
        end #}}}

      end

    end #}}}

    module Target #{{{

      class Graphviz < Default

        def generate
          @nids = []
          @labels = {}
          @fromto = []
          @labels['se'] = node_def('se','circle','')
          @labels['ee'] = node_def('ee','doublecircle','')
          pn = generate_in_list(@tree,'se')
          set_fromto pn, 'ee'
          "digraph G {\n" +
          "  rankdir=LR;\n" +
          "  node[style=rounded];\n" +
          @labels.values.map{ |e| "  #{e};\n" }.join +
          @fromto.map{ |e| "  #{quote e[0]} -> #{quote e[1]}#{e.length == 3 ? "[label=#{quote e[2]}]" : ''};\n" }.join +
          "}\n"
        end

        def id_find(nid)
          ### copy, next! would otherwise also change the node id and the entry in @nids
          nid = nid ? nid.dup : 'g0'
          while @nids.include?(nid)
            nid.next!
          end
          @nids << nid
          nid
        end

        private

          def quote(s)
            '"' + s.to_s.gsub(/\\/,'\\\\\\\\').gsub(/"/,'\\"').gsub(/\n/,'\\n') + '"'
          end

          def node_def(nid,shape,label)
            "#{quote nid}[shape=#{shape} label=#{quote label}]"
          end

          def set_fromto(pn,nid)
            if pn.is_a?(Array) && pn.length > 1
              @fromto << [pn[0],nid,pn[1]]
            else
              @fromto << [pn,nid]
            end
          end

          def print_Node(node,pn)
            nid = node.id
            label = node.label.to_s.strip
            if node.endpoints.empty? && ((!node.script.nil? && node.script.strip != '') || node.type == :scriptTask)
              @labels[nid] = node_def(nid,'component',label)
            else
              @labels[nid] = node_def(nid,'box',label)
            end
            set_fromto pn, nid
            nid
          end

          ### breaks and terminates all have the same node id, so make them unique
          def print_Break(node,pn)
            nid = id_find('b1')
            @labels[nid] = node_def(nid,'circle','^')
            set_fromto pn, nid
            nid
          end

          def print_Terminate(node,pn)
            nid = id_find('t1')
            @labels[nid] = node_def(nid,'doublecircle','terminate')
            set_fromto pn, nid
            nid
          end

          def print_Parallel(node,pn)
            nid = id_find(node.id)
            set_fromto pn, "#{nid}s"
            @labels["#{nid}s"] = node_def("#{nid}s",'diamond','AND')
            @labels["#{nid}e"] = node_def("#{nid}e",'diamond','AND')
            node.sub.each do |branch|
              pn = generate_in_list(branch,"#{nid}s")
              set_fromto pn, "#{nid}e"
            end
            "#{nid}e"
          end

          def print_Conditional(node,pn)
            nid = id_find(node.id)
            set_fromto pn, "#{nid}s"
            @labels["#{nid}s"] = node_def("#{nid}s",'diamond','x')
            @labels["#{nid}e"] = node_def("#{nid}e",'diamond','x')
            node.sub.each do |branch|
              ### branches without condition (incl. otherwise) are plain edges, the reader
              ### treats the last of them as otherwise
              pn = if branch.condition.any?
                generate_in_list(branch,["#{nid}s",branch.condition.join(' or ')])
              else
                generate_in_list(branch,"#{nid}s")
              end
              set_fromto pn, "#{nid}e"
            end
            "#{nid}e"
          end

          def print_Loop(node,pn)
            nid = id_find(node.id)
            set_fromto pn, "#{nid}s"

            @labels["#{nid}s"] = node_def("#{nid}s",'diamond','x')
            @labels["#{nid}e"] = node_def("#{nid}e",'diamond','x')

            single = node.sub.length == 1 || (node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0))
            ### if the conditional over all alternatives decides (break), loop forever
            cond = !single || node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && ')

            cn = if node.mode == :pre_test
              set_fromto "#{nid}s", "#{nid}e"
              [ ["#{nid}e", cond], "#{nid}s"]
            else
              set_fromto ["#{nid}e",cond], "#{nid}s"
              ["#{nid}s", "#{nid}e"]
            end

            pn = if single
              generate_in_list(node.sub[0],cn[0])
            else
              print_Conditional(node,cn[0])
            end
            set_fromto pn, cn[1]

            "#{nid}e"
          end

      end

    end #}}}

  end

end
