class MockDB
  def collection(name)
    MockCollection.new(:name => name)
  end
end

class MockCursor
  include Enumerable
  attr_accessor :objs
  include FromHash
  def each(&b)
    objs.each(&b)
  end
  def count
    objs.size
  end
end

class MockCollection
  include MongoPersistCollection
  attr_accessor :name
  include FromHash
  fattr(:objs) { {} }
  def remove 
    objs!
  end
  def save(doc)
    doc['_id'] = rand(10000000000)
    objs[doc['_id']] = doc
    doc['_id']
  end
  def update(ops,new_doc)
    find_raw(ops).each do |doc|
      objs[doc['_id']] = new_doc.merge('_id' => doc['_id'])
    end
  end
  def find_raw(ops={})
    objs.values.select do |h|
      ops.all? { |k,v| v === h[k.to_s] }
    end
  end
  def find(ops={})
    MockCursor.new(:objs => find_raw(ops))
  end
  def find_one(ops={})
    find_raw(ops).first
  end
end