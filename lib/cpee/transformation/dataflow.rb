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

    module Target #{{{

      class DataFlow < Default

        def generate
          res = {
            "tasks" => {},
            "gateway_conditions" => {}
          }
          generate_in_list(@tree,res)
          res
        end

        private

          def print_Node(node,res) #{{{
            if node.type == :scriptTask
              res["tasks"][node.id] = {
                "label" => node.label,
                "url" => "script",
                "script" => node.script
              }
            else

              temp = {
               "label" => node.label,
               "url" => node.endpoints[0],
              }

              if !node.script.nil?
                final = node.script['finalize']
                temp["output"] = final.split(";").to_h { |pair| pair.split("=", 2) }
              end

              if node.arguments.length > 0
                temp["input"] = node.arguments
              end
              res["tasks"][node.id] = temp
            end
            @last = node.id
            res
          end #}}}

          def print_Loop(node,res) #{{{
            gid = "#{node.id}s"
            condition = node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && ')
            res["gateway_conditions"][gid] = {
              "type" => "exclusive",
              "source_task" => @last,
              "label" => "Loop condition",
              "branches" => {"Loop condition" => condition}
            }
            if node.sub.length >=2
              node.sub.each do |branch|
               cond = branch.condition.any? ? branch.condition[0] : nil
               if  branch.length >= 1
                 generate_in_list(branch,res)
               end
              end
            end
            res
          end #}}}

          def print_Conditional(node,res) #{{{
            gid = "#{node.id}s"
            temp = {
              "type" => node.mode.to_s,
              "source_task" => @last,
              "label" => node.label,
              "branches" => {}
            }
            @last = node.id
            node.sub.each do |branch|
              cond = branch.condition.any? ? branch.condition[0] : nil
              cur_id = @last.next
              @last = cur_id
              temp["branches"][cur_id] = cond
            end
            res["gateway_conditions"][gid] = temp
            res
          end #}}}

           def print_Inclusive(node,res) #{{{
             print_Conditional(node,res)
             res
           end #}}}

          def print_Parallel(node,res) #{{{
            res
          end #}}}

          def print_Break(node,res) #{{{
            res
          end #}}}

      end

    end #}}}

  end

end
