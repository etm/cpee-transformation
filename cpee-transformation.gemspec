Gem::Specification.new do |s|
  s.name             = "cpee-transformation"
  s.version          = "1.0.7"
  s.platform         = Gem::Platform::RUBY
  s.license          = "LGPL-3.0-or-later"
  s.summary          = "CPEE Transformation between different formats"

  s.description      = "see http://cpee.org"

  s.files            = Dir['{server/*,tools/**/*,lib/**/*}'] + %w(LICENSE Rakefile cpee-transformation.gemspec README.md AUTHORS)
  s.require_path     = 'lib'
  s.extra_rdoc_files = ['README.md']
  s.bindir           = 'tools'
  s.executables      = ['trans_bpmn2-to-cpee', 'trans_bpmn2-to-mermaid', 'trans_bpmn2-to-ptml', 'trans_cpee-to-bpmn2', 'trans_cpee-to-cpee', 'trans_cpee-to-mermaid', 'trans_cpee-to-ptml', 'trans_cpee-to-text-bf', 'trans_cpee-to-text-df-poe', 'trans_cpee-to-text-df-por', 'cpee-trans', 'trans_mermaid-to-cpee', 'trans_ptml-to-cpee']

  s.required_ruby_version = '>=3.2'

  s.authors          = ['Juergen eTM Mangler', 'Nataliia Klievtsova']

  s.email            = 'juergen.mangler@gmail.com'
  s.homepage         = 'http://github.com/etm/cpee-transformation/'

  s.add_runtime_dependency 'riddl', '~> 1.0'
  s.add_runtime_dependency 'json', '~> 2.10'
  s.add_runtime_dependency 'xml-smart', '~> 0.4'
  s.add_runtime_dependency 'typhoeus', '~> 1.4'
  s.add_runtime_dependency 'highline', '~> 2.0'

  s.post_install_message = <<~MSG
    The BPMN2 target uses bpmnexport from cpee-layout (Node.js >= 22.22). By
    default npx fetches it on first use. To avoid that, run
      npm install -g cpee-layout
    and set ":bpmnexport: bpmnexport" in trans.conf of your service
    (scaffolded with cpee-trans new DIR).
  MSG
end

