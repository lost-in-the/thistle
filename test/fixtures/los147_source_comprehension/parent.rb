# frozen_string_literal: true
module Los147
  class Parent < ActiveRecord::Base
    self.abstract_class = true

    def inherited_label
      'parent label'
    end

    def display_name
      'parent display'
    end
  end
end
