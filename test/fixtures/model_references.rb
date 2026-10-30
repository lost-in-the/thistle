# Fixed harmless source; duplicate labels deliberately do not establish identity.
class User
end
class User
end
module Admin
  class User
  end
end
class Order
  def owner
    User.find(1)
  end
end
