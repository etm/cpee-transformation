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

    module Target

      class Default
        def initialize(tree)
          @tree = tree
        end

        def generate_in_list(list,res)
          list.each do |e|
            nam = e.class.name.gsub(/\w+:+/,'')
            res = send("print_#{nam}".to_sym,e,res)
          end
          res
        end

        def generate_after_list(list,res)
          post = []
          list.each do |e|
            nam = e.class.name.gsub(/\w+:+/,'')
            post += send("print_#{nam}".to_sym,e,res)
          end
          post.compact!
          post.each do |pair|
            ltext, node = pair
            res << ltext
            generate_after_list(node,res)
          end
        end

      end

    end

  end

end
