class Object
  def safe_to_mongo_hash
    respond_to?(:to_mongo_hash) ? to_mongo_hash : nil
  end
  def safe_to_mongo_object
    to_mongo_object
  end
  def ngil_obj?
    self == MongoPersist::NIL_OBJ
  end
  def can_mongo_convert?
    false
  end
end

module BaseObjects
  def to_mongo_hash
    self
  end
  def to_mongo_object
    self
  end
  def can_mongo_convert?
    true
  end
end

[Numeric,Symbol,String,BSON::ObjectId,TrueClass,FalseClass,Time].each do |cls|
  cls.send(:include,BaseObjects)
end

class NilClass
  def to_mongo_object
    self
  end
end

class Object
  def to_mongo_key
    self
  end
  def from_mongo_key
    self
  end
end

class Fixnum
  def to_mongo_key
    "#{self}-NUM"
  end
end

class String
  def from_mongo_key
    (self =~ /^(.*)-NUM$/) ? $1.to_i : self
  end
end