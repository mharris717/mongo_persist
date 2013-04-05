class ObjCursor
  attr_accessor :cursor
  include FromHash
  def each
    cursor.each { |x| yield(x.to_mongo_object) }
  end
  def to_a
    res = []
    each { |x| res << x }
    res
  end
  def count
    cursor.count
  end
end

module MongoPersistCollection
  def find_objects(*args)
    ObjCursor.new(:cursor => find(*args))
  end
  def find_one_object(*args)
    find_one(*args).to_mongo_object
  end
end

class Mongo::Collection
  include MongoPersistCollection
end