class Object
  def safe_to_mongo_hash
    to_mongo_hash
  end
  def safe_to_mongo_object
    to_mongo_object
  end
end

module BaseObjects
  def to_mongo_hash
    self
  end
  def to_mongo_object
    self
  end
end

[Numeric,Symbol,String,Mongo::ObjectID,TrueClass,FalseClass].each do |cls|
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