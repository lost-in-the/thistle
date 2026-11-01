# frozen_string_literal: true

# Handwritten display witnesses, deliberately independent of Native's naming
# formula. Pure doubles only: never create a store, load Rails or parse source.
require 'json'
require 'digest'
module RouteActionsAnswers
  GENERATION = 'a' * 64
  ROUTE = 'b' * 64
  METHOD = 'c' * 64
  OTHER = 'd' * 64
  def self.demand(value, message)
    raise message unless value
  end
  def self.rejects(error_class)
    begin
      yield
    rescue error_class
      return
    end
    raise "Expected #{error_class} refusal"
  end
  def self.identity(id = METHOD, kind = 'method')
    { 'generation'=>GENERATION,'id'=>id,'kind'=>kind,'name'=>kind == 'route' ? 'orders' : '<OrdersController#index>',
      'evidence'=>kind == 'route' ? 'runtime' : 'static','path'=>kind == 'route' ? nil : 'app/controllers/orders_controller.rb',
      'span'=>kind == 'route' ? nil : {'start_byte'=>25,'end_byte'=>54,'start_line'=>2,'end_line'=>4} }
  end
  def self.cursor(offset = 1, id = ROUTE, generation = GENERATION)
    JSON.generate(['recorded-v1',generation,Digest::SHA256.hexdigest(JSON.generate(['route_actions',id])),offset,0])
  end
  def self.page(continuation: false)
    { 'version'=>1,'generation'=>GENERATION,'root'=>identity(ROUTE,'route'),
      'route'=>{'attributes'=>{'controller'=>'orders','action'=>'index','route_path'=>'/orders(.:format)','verb'=>'GET',
        'order'=>0,'source_runtime_coherence'=>'unknown','route_constraints'=>{'request'=>{'status'=>'unknown','reason'=>'Opaque callback <unexecuted>'}}},
        'links'=>[{'relation'=>'routes_to','target'=>'orders#index','resolution'=>'unresolved'}]},
      'naming'=>{'rule'=>'ascii_snake_path_v1','owner'=>'OrdersController','action'=>'index','status'=>'conventional_labels_only','reason'=>'Custom inflections remain unknown'},
      'status'=>continuation ? 'ambiguous_static_candidates' : 'unique_static_candidate_binding_unknown',
      'candidates'=>[{'fact'=>identity,'source_status'=>'saved_source_available','source'=>{'operation'=>'source','generation'=>GENERATION,'id'=>METHOD}}],
      'candidate_count'=>{'lower_bound'=>continuation ? 2 : 1,'exact'=>!continuation},
      'coverage'=>{'capture_partial_or_unknown'=>false,'discovery_complete'=>true,'page_complete'=>!continuation,'work_partial'=>false,'remaining'=>continuation},
      'offset'=>0,'next_cursor'=>continuation ? cursor : nil,
      'continuation'=>continuation ? {'operation'=>'route_actions','generation'=>GENERATION,'id'=>ROUTE,'cursor'=>cursor} : nil,
      'unknowns'=>%w[binding coherence dispatch reachability execution].to_h { |key| [key,'unknown'] },
      'usage'=>{'source_reads'=>0},'semantics'=>'Conventional saved-label candidates; dispatch unknown.' }
  end
end
