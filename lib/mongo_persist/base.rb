class MongoWrapper
  attr_accessor :obj
  include FromHash
  def save!
    if obj.mongo_id
      obj.klass.collection.update({'_id' => obj.mongo_id},obj.to_mongo_hash)
    else
      obj.mongo_id = obj.class.collection.save(obj.to_mongo_hash)
    end
    obj
  rescue => exp
    require 'pp'
    pp obj.to_mongo_hash
    raise exp
  end
end

module MongoPersist
  NIL_OBJ = 99999
  attr_accessor :mongo_id
  #can be overriden by class.  If not, assumes that all instance variables should be saved.
  def mongo_attributes
    (instance_variables.map { |x| x[1..-1] } - ['mongo','mongo_id']).select { |x| respond_to?(x) }
  end
  def mongo_addl_attributes
    []
  end
  def mongo_child_attributes
    (mongo_attributes - self.class.mongo_reference_attributes + mongo_addl_attributes).uniq
  end
  def to_mongo_ref_hash
    {'_mongo_class' => klass.to_s, '_id' => mongo_id}
  end
  def new_hashx(attr,h,obj)
    if obj.can_mongo_convert?
      h.merge(attr => obj.to_mongo_hash) 
    else
      h
    end
  rescue
    return h
  end
  def to_mongo_hash
    res = mongo_child_attributes.inject({}) do |h,attr| 
      obj = send(attr)
      raise "#{attr} is nil" unless obj
      new_hashx(attr,h,obj)
    end.merge("_mongo_class" => self.class.to_s)
    klass.mongo_reference_attributes.each do |attr|
      val = send(attr)
      res[attr] = val.to_mongo_ref_hash if val
    end
    res
  end
  def from_mongo_hash(h)
    h = h.map_value { |v| v.safe_to_mongo_object }
    from_hash(h)
  end
  fattr(:mongo) { MongoWrapper.new(:obj => self) }
  
  module ClassMethods
    dsl_method(:mongo_reference_attributes) { [] }
    def default_collection_name
      to_s.downcase.pluralize
    end
    fattr(:collection) { db.collection(default_collection_name) }
    def new_with_nil_args
      args = (1..(instance_method(:initialize).arity)).map { |x| nil }
      new(*args)
    end
    def from_mongo_hash(h)
      new_with_nil_args.tap { |x| x.from_mongo_hash(h) }
    end
    def mongo_connection(ops)
      ops.each { |k,v| send("#{k}=",v) }
    end
  end
  def self.included(mod)
    super(mod)
    mod.send(:include,FromHash)
    mod.send(:extend,ClassMethods)
  end
end
