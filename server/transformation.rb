#!/usr/bin/ruby
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

require 'rubygems'
require 'riddl/server'
require 'xml/smart'
if File.exist?(File.dirname(__FILE__) + '/../lib/cpee/transformation/bpmn2')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/cpee/transformation/bpmn2')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/cpee/transformation/transformer')
  require File.expand_path(File.dirname(__FILE__) + '/../lib/cpee/transformation/cpee')
else
  require 'cpee/transformation/bpmn2'
  require 'cpee/transformation/transformer'
  require 'cpee/transformation/cpee'
end
require 'json'

class ExtractDescription < Riddl::Implementation #{{{
  def response
    bpmn2 = CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
    trans = CPEE::Transformation::Transformer.new(bpmn2)
    trans.build_traces
    trans.build_tree(false)
    xml = trans.generate_model(CPEE::Transformation::Target::CPEE)

    return Riddl::Parameter::Complex.new("description","text/xml",xml.to_s)
  end
end #}}}

class ExtractDataelements < Riddl::Implementation #{{{
  def response
    ret = []

    bpmn2 = CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
    bpmn2.dataelements.each do |k,v|
      ret << Riddl::Parameter::Simple.new("name",k)
      ret << Riddl::Parameter::Simple.new("value",v)
    end

    ret
  end
end #}}}

class ExtractEndpoints < Riddl::Implementation #{{{
  def response
    ret = []

    bpmn2 = CPEE::Transformation::Source::BPMN2.new(@p[0].value.read)
    bpmn2.endpoints.each do |k,v|
      ret << Riddl::Parameter::Simple.new("name",k)
      ret << Riddl::Parameter::Simple.new("value",v)
    end

    ret
  end
end #}}}

Riddl::Server.new(File.dirname(__FILE__) + '/transformation_dec.xml', :port => 9295) do
  accessible_description true
  cross_site_xhr true

  interface 'main' do
    run ExtractDescription if post 'dedesc'
    run ExtractDataelements if post 'dadesc'
    run ExtractEndpoints if post 'endesc'
  end
end.loop!
