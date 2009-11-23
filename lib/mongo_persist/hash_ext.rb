module MongoHash
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
    return map_value { |v| v.safe_to_mongo_object } unless mongo_class
    if naked_reference?
      mongo_class.collection.find_one_object('_id' => get_mongo_id)
    else
      mongo_class.from_mongo_hash(to_mongo_hash_for_obj)
    end
  end
  def to_mongo_hash
    res = {}
    each { |k,v| res[k.safe_to_mongo_hash] = v.safe_to_mongo_hash }
    res
  end
end

class Hash
  include MongoHash
end