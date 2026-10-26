#!/usr/bin/ruby
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
# along with CPEE-TRANSFORMATION (file LICENSE in the main directory). If not,
# see <http://www.gnu.org/licenses/>.

require 'riddl/server'
require 'json'
require 'timeout'
require_relative 'bpmn2'
require_relative 'mermaid'
require_relative 'graphviz'
require_relative 'transformer'
require_relative 'cpee'

module CPEE

  module Transformation

    module Service

      SERVER = File.expand_path(File.join(__dir__,'implementation.xml'))

      class ExtractDescription < Riddl::Implementation #{{{
        def response
          source = case @h['RIDDL_DECLARATION_PATH'].split('/')[-1]
            when 'cpee'
              CPEE::Transformation::Source::CPEE.new(@p[0].value.read)
            when 'bpmn2'
              CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
            when 'mermaid'
              CPEE::Transformation::Source::Mermaid.new(@p[0].value.read)
            when 'graphviz'
              CPEE::Transformation::Source::Graphviz.new(@p[0].value.read)
            else
              nil
          end
          mtype, target = case @h['RIDDL_DECLARATION_PATH'].split('/')[-2]
            when 'cpee'
              ['text/xml', CPEE::Transformation::Target::CPEE]
            when 'mermaid'
              ['text/plain', CPEE::Transformation::Target::Mermaid]
            when 'text-bf'
              ['text/plain', CPEE::Transformation::Target::Text_bf]
            when 'text-df-PO-extended'
              ['text/plain', CPEE::Transformation::Target::Text_df_PO_extended]
            when 'text-df-PO-reduced'
              ['text/plain', CPEE::Transformation::Target::Text_df_PO_reduced]
            else
              [nil,nil]
          end
          if source.nil? || target.nil?
            @status = 500
          else
            trans = nil
            begin
              Timeout.timeout(15) do
                trans = CPEE::Transformation::Transformer.new(source)
                trans.build_traces
                trans.build_tree(false)
              end
            rescue Timeout::Error => err
              puts 'broken model'
              puts err.message
              puts err.backtrace
            ensure
              if trans
                xml = trans.generate_model(target)
                return Riddl::Parameter::Complex.new("description",mtype,xml.to_s)
              end
            end
          end
        end
      end #}}}

      class ExtractDataelements < Riddl::Implementation #{{{
        def response
          ret = []

          if @h['RIDDL_DECLARATION_PATH'].split('/')[-1] == 'bpmn2'
            bpmn2 = CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
            bpmn2.dataelements.each do |k,v|
              ret << Riddl::Parameter::Simple.new("name",k)
              ret << Riddl::Parameter::Simple.new("value",v)
            end
          end

          ret
        end
      end #}}}

      class ExtractEndpoints < Riddl::Implementation #{{{
        def response
          ret = []

          if @h['RIDDL_DECLARATION_PATH'].split('/')[-1] == 'bpmn2'
            bpmn2 = CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
            bpmn2.endpoints.each do |k,v|
              ret << Riddl::Parameter::Simple.new("name",k)
              ret << Riddl::Parameter::Simple.new("value",v)
            end
          end

          ret
        end
      end #}}}

      def self::implementation(opts)
        Proc.new do
          interface 'xml_cpee' do
            run ExtractDescription if post 'xmldedesc'
            run ExtractDataelements if post 'xmldadesc'
            run ExtractEndpoints if post 'xmlendesc'
          end
          interface 'text_cpee' do
            run ExtractDescription if post 'plaindedesc'
            run ExtractDataelements if post 'plaindadesc'
            run ExtractEndpoints if post 'plainendesc'
          end
          interface 'xml_text' do
            run ExtractDescription if post 'xmldedesc'
            run ExtractDataelements if post 'xmldadesc'
            run ExtractEndpoints if post 'xmlendesc'
          end
        end
      end

    end

  end

end
