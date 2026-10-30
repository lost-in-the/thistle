Kit::Button.new(:top)
{ primary: Kit::Button.new(:top_hash) }
def top_render
  { primary: Kit::Button.new(:top_method_hash) }
end
