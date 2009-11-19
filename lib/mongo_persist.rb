require 'rubygems'
require 'mongo'
require 'activesupport'
require 'fattr'
require File.dirname(__FILE__) + "/mongo_persist/util"

class Object
  def safe_to_mongo_hash
    sos(:to_mongo_hash)
  end
  def safe_to_mongo_object
    sos(:to_mongo_object)
  end
end

class Array
  def to_mongo_hash
    map { |x| x.safe_to_mongo_hash }
  end
  def to_mongo_object
    map { |x| x.safe_to_mongo_object }
  end
end

class Hash
  def get_mongo_id
    ['_id','mongo_id'].each { |x| return self[x] if self[x] }
    nil
  end
  def naked_reference?
    (keys - ['_id','_mongo_class','mongo_id']).empty? && !!get_mongo_id
  end
  def mongo_class
    self['_mongo_class'] ? eval(self['_mongo_class']) : nil
  end
  def to_mongo_hash_for_obj
    h = reject { |k,v| k == '_mongo_class' }
    h['mongo_id'] = h['_id'] if h['_id']
    h.reject { |k,v| k == '_id' }
  end
  def to_mongo_object
    return self unless mongo_class
    if naked_reference?
      mongo_class.collection.find_one_object('_id' => get_mongo_id)
    else
      mongo_class.from_mongo_hash(to_mongo_hash_for_obj)
    end
  end
end

module MongoPersist
  attr_accessor :mongo_id
  #can be overriden by class.  If not, assumes that all instance variables should be saved.
  def mongo_attributes
    instance_variables.map { |x| x[1..-1] }
  end
  def mongo_child_attributes
    mongo_attributes - self.class.mongo_reference_attributes
  end
  def to_mongo_hash
    res = mongo_child_attributes.inject({}) { |h,attr| h.merge(attr => send(attr).safe_to_mongo_hash) }.merge("_mongo_class" => self.class.to_s)
    klass.mongo_reference_attributes.each do |attr|
      obj = send(attr)
      res[attr] = {'_mongo_class' => obj.class.to_s, '_id' => send(attr).mongo_id}
    end
    res
  end
  def from_mongo_hash(h)
    h = h.map_value { |v| v.safe_to_mongo_object }
    from_hash(h)
  end
  def mongo_save!
    if mongo_id
      klass.collection.update({'_id' => mongo_id},to_mongo_hash)
    else
      self.mongo_id = self.class.collection.save(to_mongo_hash)
    end
    self
  end
  
  module ClassMethods
    dsl_method(:mongo_reference_attributes) { [] }
    def default_collection_name
      to_s.downcase.pluralize
    end
    fattr(:collection) { db.collection(default_collection_name) }
    def from_mongo_hash(h)
      new.tap { |x| x.from_mongo_hash(h) }
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

class ObjCursor
  attr_accessor :cursor
  include FromHash
  def each
    cursor.each { |x| yield(x.to_mongo_object) }
  end
  def count
    cursor.count
  end
end

class Mongo::Collection
  def find_objects(*args)
    ObjCursor.new(:cursor => find(*args))
  end
  def find_one_object(*args)
    find_one(*args).to_mongo_object
  end
end