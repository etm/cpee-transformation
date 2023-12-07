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

module CPEE

  module Transformation

    module Target

      class Text_bf < Default

        def generate
          res = "The process contains the following main elements:\n"
          generate_after_list(@tree,res)
          res << "After this the process ends."
          res
        end

        private
          def restore_where(orig)
            @where, @first, @num = orig
          end
          def reset_where(where=nil,num=0)
            orig = [@where,@first,@num]
            @where = where
            @first = 0
            @num = num
            orig
          end

          def get_next(what) #{{{
            @first ||= 0
            @first += 1
            "  * #{what}\n"
          end #}}}

          def get_meth(m) #{{{
            case m
              when "POST"; "posts to"
              when "DELETE"; "deletes"
              when "GET"; "gets"
              when "PUT"; "updates"
              when "PATCH"; "updates"
              else
                  "calls"
            end
          end #}}}

          def get_num(n) #{{{
            case n
              when 0; "first"
              when 1; "second"
              when 2; "third"
              when 3; "fourth"
              when 4; "fifth"
              when 5; "sixth"
              when 6; "seventh"
              when 7; "eight"
              when 8; "ninth"
              when 9; "tenth"
            end
          end #}}}

          def print_Break(node,res)
            res << get_next("at this point the innermost loop is exited. ")
            [nil]
          end

          def print_Loop(node,res)
            post = []

            @loop ||= 0
            @loop += 1
            loop = @loop
            logic = Proc.new do
              if node.mode == :pre_test
                if node.sub[0].condition.empty?
                  res << get_next("an infinite loop (no condidition), furthermore referred to as L#{loop}.")
                else
                  res << get_next("a loop, which starts if the condition \"#{node.sub[0].condition.join(' and ')}\" is met, furthermore referred to as L#{loop}.")
                end
                post << ["The loop L#{loop} contains the following elements:\n", node.sub[0] ]
              else
                if node.sub[0].condition.empty?
                  res << get_next("the start of a loop, furthermore referred to as L#{loop}.\n    If the loop ends,\n    L#{loop} is visited again.")
                else
                  res << get_next("the start of a loop, furthermore referred to as L#{loop}.\n    If the loop ends, and the condition \"#{node.sub[0].condition.join(' and ')}\" is met,\n    L#{loop} is visited again.")
                end
                post << ["The loop L#{loop} contains the following elements:\n", node.sub[0] ]
              end
            end
            if node.sub.length == 2 && node.sub[1].condition.empty? && ((node.sub[1].length == 1 && node.sub[1][0].class.name.gsub(/\w+:+/,'') == 'Break') ||  node.sub[1].length == 0)
              logic.call
            else
              if node.sub.length == 1
                logic.call
              else
                print_Conditional(node,res)
              end
            end
            post
          end

          def print_Node(node,res)
            if node.endpoints.empty? && !node.script.nil? && node.script.strip != ''
              res << get_next("a script task with the id a#{node.niceid}")
            else
              lab = node.label.gsub(/"/,"\\\"").strip rescue ''
              if lab.length > 0 && node.endpoints.any?
                res << get_next("a task with the id a#{node.niceid} and the label \"#{lab}\" which #{get_meth(node.methods.join(','))} the endpoint #{node.endpoints.join(',')}")
              elsif lab.length == 0 && node.endpoints.any?
                res << get_next("a task with the id a#{node.niceid} which #{get_meth(node.methods.join(','))} the endpoint #{node.endpoints.join(',')}")
              elsif lab.length > 0 && node.endpoints.empty?
                res << get_next("a task with the id a#{node.niceid} and the label \"#{lab}\"")
              else
                res << get_next("a task with the id a#{node.niceid}")
              end
              if node.parameters.length > 0
                res << "It is called with the following parameters: "
                node.parameters.each do |k,v|
                  res << "#{k} is \"#{v}\""
                end
              end
            end
            [nil]
          end

          def print_Parallel(node,res)
            post  = []

            @parallel ||= 0
            @parallel += 1
            parallel = @parallel
            ltext = ""
            if node.wait == "-1" && node.cancel == "last"
              ltext << "a parallel gateway with #{node.sub.length} branches, furthermore dubbed PG#{parallel}. "
            elsif node.wait == "1" && node.cancel == "first"
              ltext << "an event-based gateway with #{node.sub.length} branches. "
            elsif node.cancel == "first"
              if node.wait == -1 || node.wait == 0
                ltext << "a parallel gateway with #{node.sub.length} branches. "
              else
                ltext << "a parallel event-based gateway which waits for #{node.wait} out of #{node.sub.length} branches. "
              end
            else
              ltext << "a complex gateway with #{node.sub.length} branches. "
            end
            node.sub.each_with_index do |branch,index|
              post << ["The #{get_num(index)} branch of PG#{parallel} contains the following elements:\n", branch ]
            end
            res << get_next(ltext)
            post
          end

          def print_Conditional(node,res)
            post  = []

            @decision ||= 0
            @decision += 1
            decision = @decision
            ntext = "an #{node.mode} decision with #{node.sub.length} branches. This decision will be furthermore refered to as D#{decision}. "
            node.sub.each_with_index do |branch, index|
              if branch.condition? && branch.condition.length > 0
                ntext << "\n    The #{get_num(index)} branch of D#{decision} is executed if the condition is \"#{branch.condition.join(' or ')}\". "
              else
                ntext << '' # empty condition.
              end
              post << [ "The #{get_num(index)} branch of D#{decision} contains the following elements:\n", branch ]
            end
            res << get_next(ntext)
            # if ### default branch handling
            #   res << "If none of the conditions match, a default branch is executed. The default branch contains "
            #   post << x
            # end
            post
          end

      end

    end

  end

end
