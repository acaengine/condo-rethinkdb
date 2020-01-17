$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "condo-rethinkdb/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
    s.name        = "condo-rethinkdb"
    s.version     = CondoRethinkdb::VERSION
    s.authors     = ["Stephen von Takach"]
    s.email       = ["steve@cotag.me"]
    s.homepage    = "http://cotag.me/"
    s.summary     = "RethinkDB backend for the Condo project."
    s.description = "Provides database storage utilising RethinkDB."

    s.files = Dir["{app,config,db,lib}/**/*"] + ["LGPL3-LICENSE", "Rakefile", "README.textile"]
    s.test_files = Dir["test/**/*"]

    s.add_dependency "rails", ">= 4.0.0"
    s.add_dependency "condo"
    s.add_dependency "nobrainer"
end
