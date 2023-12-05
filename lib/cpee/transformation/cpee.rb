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

require File.expand_path(File.dirname(__FILE__) + '/target')
require 'xml/smart'

module CPEE

  module Transformation

    module Target

      class CPEE < Default

        def generate
          res = XML::Smart.string("<description xmlns='http://cpee.org/ns/description/1.0'/>")
          res.register_namespace 'd', 'http://cpee.org/ns/description/1.0'
          generate_for_list(@tree,res.root)
          res.to_s
        end

        private
          def print_Break(node,res)
            res.add('escape')
          end

          def print_Loop(node,res)
            if node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0)
              s1 = res.add('loop', 'mode' => node.mode, 'condition' => node.sub[0].condition.empty? ? 'true' : node.sub[0].condition.join(' && '))
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
            if node.endpoints.empty? && !node.script.nil? && node.script.strip != ''
              n = res.add('d:manipulate', node.script, 'id' => "a#{node.niceid}")
              n.attributes['output'] = node.script_var unless node.script_var.nil?
              n.attributes['language'] = node.script_type unless node.script_type.nil?
            else
              n   = res.add('d:call', 'id' => "a#{node.niceid}", 'endpoint' => node.endpoints.join(','))
              p   = n.add('d:parameters')
                    p.add('d:label',"\"#{node.label.gsub(/"/,"\\\"")}\"")
                    p.add('d:method',node.methods.join(',') || 'post')
                    p.add('d:type',":#{node.type}")
                    p.add('d:mid',"'#{node.id}'")
              par = p.add('d:arguments')
              node.parameters.each do |k,v|
                par.add(k,v)
              end
              if !node.script.nil? && node.script.strip != ''
                x = n.add('d:finalize',node.script)
                x.attributes['output'] = node.script_var unless node.script_var.nil?
                x.attributes['language'] = node.script_type unless node.script_type.nil?
              end
            end
          end

          def print_Parallel(node,res)
            s1 = res.add('parallel','wait' => node.wait, 'cancel' => node.cancel)
            node.sub.each do |branch|
              s2 = s1.add('parallel_branch')
              generate_for_list(branch,s2)
            end
            s1
          end

          def print_Conditional(node,res)
            s1 = res.add('d:choose', 'mode' => node.mode)
            node.sub.each do |branch|
              s2 = if branch.condition.any?
                a = s1.add('d:alternative','condition' => branch.condition.join(' or '))
                a.attributes['language'] = branch.condition_type unless branch.condition_type.nil?
                a
              else
                s1.add('d:alternative', 'condition' => '')
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

    end

  end

end
