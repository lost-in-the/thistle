class PlainCaller
  def perform
    Widget.build
  end
end

class RootCaller
  def perform
    ::Widget.build
  end
end

module Other
  class NestedCaller
    def perform
      ::Widget.build
    end
  end
end

class ShopCaller
  def perform
    Shop::Widget.build
  end
end

class RootShopCaller
  def perform
    ::Shop::Widget.build
  end
end
