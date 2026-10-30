class Holder
  wrapper do
    include Tagged
    def hidden
      Kit::Button.new(:unsupported)
    end
  end
end
