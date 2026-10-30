module LexicalDemo
  Kit::Button.new(:module_body)
  class Screen
    Kit::Button.new(:class_body)
    def render
      { primary: Kit::Button.new(:method_hash) }
      [1].each do
        Kit::Button.new(:method_block)
      end
    end
  end
end
