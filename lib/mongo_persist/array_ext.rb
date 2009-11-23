class Array
  def to_mongo_hash
    map { |x| x.safe_to_mongo_hash }
  end
  def to_mongo_object
    map { |x| x.safe_to_mongo_object }
  end
  def to_mongo_ref_hash
    map { |x| x.to_mongo_ref_hash }
  end
end