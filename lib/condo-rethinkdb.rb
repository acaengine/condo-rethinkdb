require 'condo'
require 'condo-rethinkdb/engine'
require 'condo/backend/rethinkdb'

#::Condo::Application.backend = Condo::Backend::Couchbase
silence_warnings { ::Condo.const_set(:Store, ::Condo::Backend::RethinkDB) }
