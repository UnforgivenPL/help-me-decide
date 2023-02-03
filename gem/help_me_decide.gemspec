# frozen_string_literal: true

Gem::Specification.new do |g|
  g.name = 'help_me_decide'
  g.version = '0.1.0'
  g.licenses = ['Apache 2']
  g.summary = 'A question-based filtering tool to navigate through datasets.'
  g.author = 'Miki / Unforgiven.pl'
  g.email = 'support@unforgiven.pl'
  g.homepage = 'https://www.unforgiven.pl/help-me-decide'
  g.files = %w[lib/help_me_decide.rb lib/help_me_decide/dataset.rb lib/help_me_decide/feature_definition.rb lib/help_me_decide/feature_definitions.rb lib/help_me_decide/no_questions.rb lib/help_me_decide/strategies.rb]
end
