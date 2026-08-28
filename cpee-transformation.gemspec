Gem::Specification.new do |s|
  s.name             = "cpee-transformation"
  s.version          = "1.0.2"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0-or-later"
  s.summary          = "CPEE Transformation between different formats"

  s.description      = "see http://cpee.org"

  s.files            = Dir['{server/*,tools/**/*,lib/**/*}'] + %w(LICENSE Rakefile cpee-transformation.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['bpmn2_to_cpee.rb', 'bpmn2_to_mermaid.rb', 'bpmn2_to_ptml.rb', 'cpee_to_cpee.rb', 'cpee_to_mermaid.rb', 'cpee_to_ptml.rb', 'cpee_to_text_bf.rb', 'cpee_to_text_df-poe.rb', 'cpee_to_text_df-por.rb', 'cpee-trans', 'mermaid_to_cpee.rb', 'ptml_to_cpee.rb']

  s.required_ruby_version = '>=3.2'

  s.authors          = ['Juergen eTM Mangler', 'Nataliia Klievtsova']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://github.com/etm/cpee-transformation/'

  s.add_runtime_dependency 'riddl', '~> 1.0'
  s.add_runtime_dependency 'json', '~> 2.10'
  s.add_runtime_dependency 'xml-smart', '~> 0.4'
  s.add_runtime_dependency 'typhoeus', '~> 1.4'
  s.add_runtime_dependency 'highline', '~> 2.0'
end

