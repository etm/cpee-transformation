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

        def output_to_document(doc)
          generate_for_list(@tree,doc.root)
          doc.to_s
        end

        def generate_for_list(list,res)
          list.each do |e|
            nam = e.class.name.gsub(/\w+:+/,'')
            send("print_#{nam}".to_sym,e,res)
          end
        end

      end

    end

  end

end
