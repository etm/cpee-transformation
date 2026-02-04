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

      class Text_df_PO_extended < Default

        def generate
          res = ""
          generate_in_list(@tree,res)
          res.sub!(/.\s*$/,', and the process ends.')
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
            if @phrases.nil?
              phrases = ["Then #{what} occurs. ", "Afterwards, this is followed by #{what}. ", "Subsequently, this is followed by #{what}. ", "Subsequently #{what} occurs. "]
            end
            @first ||= 0
            @first += 1
            if @num == 1
              "The only entry #{@where.nil? ? '' : @where + ' ' }is #{what}. "
            else
              if @first == 1 && !@where.nil?
                "The first entry in #{@where.nil? ? '' : @where + ' '}is #{what}. "
              elsif @first == 1 && @where.nil?
                "First, #{what} occurs. "
              else
                phrase = phrases.shift
                phrases.append phrase
                phrase
              end
            end
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
            res << "At this point the innermost loop is exited. "
          end

          def print_Loop(node,res)
            @loop ||= 0
            @loop += 1
            loop = @loop
            logic = Proc.new do
              if node.mode == :pre_test
                if node.sub[0].condition.empty?
                  res << get_next("an infinite loop (no condidition)")
                else
                  res << get_next("a loop, which starts if the condition \"#{node.sub[0].condition.join(' and ')}\" is met,")
                end
                generate_in_list(node.sub[0],res)
              else
                res << get_next("the start of a loop")
                generate_in_list(node.sub[0],res)
                if node.sub[0].condition.empty?
                  res << "If we reach this point we loop back. "
                else
                  res << "After this we loop back, if the condition \"#{node.sub[0].condition.join(' and ')}\" evaluates to true. "
                end
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
              if node.arguments.length > 0
                res << "It is called with the following arguments: "
                params = []
                node.arguments.each do |k,v|
                  params << "#{k} is \"#{v}\""
                end
                res << params.join(', ') + '. '
              end
            end
          end

          def print_Parallel(node,res)
            @parallel ||= 0
            @parallel += 1
            parallel = @parallel
            if node.wait == "-1" && node.cancel == "last"
              res << get_next("a parallel gateway with #{node.sub.length} branches, furthermore dubbed PG#{parallel},")
            elsif node.wait == "1" && node.cancel == "first"
              res << get_next("an event-based gateway with #{node.sub.length} branches")
            elsif node.cancel == "first"
              if node.wait == -1 || node.wait == 0
                res << get_next("a parallel gateway with #{node.sub.length} branches")
              else
                res << get_next("a parallel event-based gateway which waits for #{node.wait} out of #{node.sub.length} branches")
              end
            else
              res << get_next("a complex gateway with #{node.sub.length} branches")
            end
            node.sub.each_with_index do |branch,index|
              orig = reset_where "in the #{get_num(index)} parallel branch of PG#{parallel}", node.sub.length
              generate_in_list(branch,res)
              restore_where orig
            end
            res << "Finally the branches of PG#{parallel} are joined. "
          end

          def print_Conditional(node,res)
            @decision ||= 0
            @decision += 1
            decision = @decision
            res << get_next("an #{node.mode} decision with #{node.sub.length} branches")
            res << "This decision will be furthermore refered to as D#{decision}. "
            node.sub.each_with_index do |branch, index|
              if branch.condition? && branch.condition.length > 0
                res << "The #{get_num(index)} branch of D#{decision} is executed if the condition is \"#{branch.condition.join(' or ')}\". "
              else
                res << '' # empty condition.
              end
              orig = reset_where "in the #{get_num(index)} branch of D#{decision}", branch.length
              generate_in_list(branch,res)
              restore_where orig
            end
            # if ### default branch handling
            #   res << "If none of the conditions match, a default branch is executed. The default branch contains "
            #   generate_in_list(x,res)
            # end
            res << "Following this, all branches of D#{decision} are finished. "
          end

      end

    end

  end

end
