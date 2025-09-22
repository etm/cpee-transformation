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

    module Source #{{{

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
              pp a
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

    end #}}}

    module Target #{{{

      class Mermaid < Default

        def generate
          @gwc = 0
          @labels = {}
          @fromto = []
          @labels['se'] = "se:startevent:((startevent))"
          @labels['ee'] = "ee:endevent:((endevent))"
          pn = generate_in_list(@tree,'se')
          set_fromto pn, 'ee'
          "flowchart LR\n" + @fromto.map{ |e| "#{@labels[e[0]]}-->#{e.length == 3 ? e[2] : ''}#{@labels[e[1]]}"}.join("\n")
        end

        private

          def set_fromto(pn,nid)
            if pn.is_a?(Array) && pn.length > 1
              @fromto << [pn[0],nid,pn[1]]
            else
              @fromto << [pn,nid]
            end
          end

          def print_Node(node,pn)
            nid = node.id
            if node.endpoints.empty? && ((!node.script.nil? && node.script.strip != '') || node.type == :scriptTask)
              @labels[nid] = "#{nid}:scripttask:(#{node.label.gsub(/\(/,"\\(").gsub(/\)/,"\\)")})"
            else
              @labels[nid] = "#{nid}:task:(#{node.label.gsub(/\(/,"\\(").gsub(/\)/,"\\)")})"
            end
            set_fromto pn, nid
            nid
          end

          def print_Break(node,pn)
            nid = node.id
            @labels[nid] = "#{nid}:escalate:((^))"
            set_fromto pn, nid
            nid
          end

          def print_Parallel(node,pn)
            nid = "gw#{(@gwc += 1)}"
            set_fromto pn, "#{nid}s"
            @labels["#{nid}s"] = "#{nid}s:parallelgateway:{AND}"
            @labels["#{nid}e"] = "#{nid}e:parallelgateway:{AND}"
            node.sub.each do |branch|
              pn = generate_in_list(branch,["#{nid}s"])
              set_fromto pn, "#{nid}e"
            end
            "#{nid}e"
          end

          def print_Conditional(node,pn)
            nid = "gw#{(@gwc += 1)}"
            set_fromto pn, "#{nid}s"
            @labels["#{nid}s"] = "#{nid}s:exclusivegateway:{x}"
            @labels["#{nid}e"] = "#{nid}e:exclusivegateway:{x}"
            node.sub.each do |branch|
              pn = if branch.condition.any?
                generate_in_list(branch,["#{nid}s","|\"#{branch.condition.join(' or ')}\"|"])
              else
                if branch.otherwise
                  generate_in_list(branch,["#{nid}s","|\"|\"|"])
                else
                  generate_in_list(branch,"#{nid}s")
                end
              end
              set_fromto pn, "#{nid}e"
            end
            "#{nid}e"
          end

          def print_Loop(node,pn)
            nid = "gw#{(@gwc += 1)}"
            set_fromto pn, "#{nid}s"

            @labels["#{nid}s"] = "#{nid}s:exclusivegateway:{x}"
            @labels["#{nid}e"] = "#{nid}e:exclusivegateway:{x}"

            cn = if node.mode == :pre_test
              set_fromto "#{nid}s", "#{nid}e"
              [ ["#{nid}e", "|\"#{node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && ')}\"|"], "#{nid}s"]
            else
              set_fromto ["#{nid}e","|\"#{node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && ')}\"|"], "#{nid}s"
              ["#{nid}s", "#{nid}e"]
            end

            pn = if node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0)
              generate_in_list(node.sub[0],cn[0])
            else
              if node.sub.length == 1
                generate_in_list(node.sub[0],cn[0])
              else
                print_Conditional(node,cn[0])
              end
            end
            set_fromto pn, cn[1]

            "#{nid}e"
          end

      end

    end #}}}

  end

end
