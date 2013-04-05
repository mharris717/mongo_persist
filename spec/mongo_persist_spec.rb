require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require_lib "/code/mongo_scope/lib/mongo_scope"
require 'mharris_ext'

def on_rcr?
  dir = File.expand_path(File.dirname(__FILE__))
  !!(dir =~ /\/mnt\/repos/)#.tap { |x| puts "Dir #{dir} rcr? #{x}" }
end

def db
  if on_rcr?
    require File.dirname(__FILE__) + "/mocks"
    MockDB.new
  else
    Mongo::Connection.new.db('test-db')
  end
end

class Order
  include MongoPersist
  attr_accessor :po_number, :customers, :some_hash
  mongo_reference_attributes ['customers']
  fattr(:order_products) { [] }
  def products
    order_products.map { |x| x.product }
  end
  def subtotal
    order_products.map { |x| x.subtotal }.sum
  end
end

class OrderProduct
  include MongoPersist
  attr_accessor :unit_price, :quantity, :product
  mongo_reference_attributes ['product']
  def subtotal
    quantity.to_f * unit_price
  end
end

class Product
  include MongoPersist
  attr_accessor :name
end

class Customer
  include MongoPersist
  attr_accessor :email
end

class Foo
  include MongoPersist
  attr_accessor :bar
  def initialize(b)
    @bar = b
  end
  def self.fgrom_mongo_hash(ops)
    new(nil).from_hash(ops)
  end
end
if true
# too many assertions per test, too many "this is how things should be before i check the point of this test" assertions
describe MongoPersist do
  before do
    $abc = false
    [Order,Product].each { |x| x.collection.remove }
    @products = [Product.new(:name => 'Leather Couch'),Product.new(:name => 'Maroon Chair')].each { |x| x.mongo.save! }
    @customers = [Customer.new(:email => 'a'),Customer.new(:email => 'b')].each { |x| x.mongo.save! }

    @orders = []
    @orders << Order.new(:customers => @customers, :po_number => 1234, :order_products => [OrderProduct.new(:unit_price => 1000, :quantity => 1, :product => @products[0])]).mongo.save!
    @orders << Order.new(:customers => @customers, :po_number => 1235, :order_products => [OrderProduct.new(:unit_price => 200, :quantity => 2, :product => @products[1])]).mongo.save!
  end
  it 'should have id' do
    @orders.first.mongo_id.should be
  end
  it 'product should have name' do
    #raise Order.collection.find_one_object.inspect
    Order.collection.find_one_object.order_products.first.product.name.should be
  end
  it 'naked reference' do
    h = {'mongo_id' => @products.first.mongo_id}
    h.should be_naked_reference
    h['name'] = 'abc'
    h.should_not be_naked_reference
  end
  it 'to_mongo_object ref' do
    h = {'_id' => @products.first.mongo_id, '_mongo_class' => 'Product'}
    h.to_mongo_object.name.should == 'Leather Couch'
    h['name'] = 'Leather Couch'
    h.to_mongo_object.name.should == 'Leather Couch'
  end
  it 'updates' do
    @products.first.from_hash(:name => 'White Leather Couch').mongo.save!
    Product.collection.find.count.should == 2
    Product.collection.find_objects(:name => /Leather/).count.should == 1
    Product.collection.find_one_object(:name => /Leather/).name.should == 'White Leather Couch'
  end
  it 'reference loading' do
    @products.first.from_hash(:name => 'White Leather Couch').mongo.save!
    Order.collection.find_one_object(:po_number => 1234).products.first.name.should == 'White Leather Couch'
  end
  it 'customers' do
    @customers.first.from_hash(:email => 'z').mongo.save!
    Order.collection.find_one_object.customers.first.email.should == 'z'
  end
  it 'saving hashes' do
    o = Order.new(:po_number => 1, :some_hash => {'1' => Product.new(:name => 'Chair')})
    o.mongo.save!
    Order.collection.find_one_object(:po_number => 1).some_hash['1'].name.should == 'Chair'
    Order.collection.find_one_object(:po_number => 1234).subtotal.should == 1000
  end
  it 'saving reference hashes' do
    p = Product.new(:name => 'Chair')
    p.mongo.save!
    o = Order.new(:po_number => 1, :some_hash => {'1' => p})
    o.mongo.save!
    Order.collection.find_one_object(:po_number => 1).some_hash['1'].name.should == 'Chair'
    Order.collection.find_one_object(:po_number => 1234).subtotal.should == 1000
  end
  it 'obj with own constructor' do
    Foo.collection.remove
    Foo.new(14).mongo.save!
    Foo.collection.find_one_object.bar.should == 14
  end
  it 'hash with number key' do
    Foo.collection.remove
    f = Foo.new(14)
    f.bar = {1 => 2}
    f.mongo.save!
    Foo.collection.find_one_object.bar.keys.should == [1]
  end
  it 'grouping' do
   if false; coll = db.collection('abc')
    coll.remove
    coll.save('a' => 'a', 'b' => 1)
    coll.save("a" => 'a', 'b' => 3)
    coll.save('a' => 'b', 'b' => 2)

    # reduce_function = "function (obj, prev) { prev.count += obj.b; }"
    # code = Mongo::Code.new(reduce_function)
    # res = coll.group(['a'], {}, {"count" => 0},code)
    
    res = coll.sum_by_raw(:key => 'a', :sum_field => 'b')
    
    res.find { |x| x['a'] == 'a'}['count'].should == 4
    res.find { |x| x['a'] == 'b'}['count'].should == 2
    
    res = coll.sum_by(:key => 'a', :sum_field => 'b').should == {'a' => 4, 'b' => 2}; end
  end
end
end
describe "n+1" do
  before do
    $proxy = true
    [Order,Product].each { |x| x.collection.remove }
    @products = [Product.new(:name => 'Leather Couch'),Product.new(:name => 'Maroon Chair')].each { |x| x.mongo.save! }
    #@products = (1..5000).map { |x| Product.new(:name => x.to_s) }
    @products.each { |x| x.mongo.save! }
    @order_products = @products.map { |x| OrderProduct.new(:product => x) }
    @order = Order.new(:order_products => @order_products).mongo.save!
  end
  it 'loading products should only do 1 lookup' do
    #mock.proxy(Product.collection).find()
    #Order.collection.find_one_object.products.map { |x| x.name }.should == @products.map { |x| x.name }
  end
  it 'speed test' do
    tm('with proxy') do
      Order.collection.find_one_object.products.each { |x| x.name }
    end
    tm('without proxy') do
      $proxy = false
      Order.collection.find_one_object.products.each { |x| x.name }
    end
  end
end

class Mongo::Collection
  def sum_by_raw(ops)
    reduce_function = "function (obj, prev) { prev.count += (obj.#{ops[:sum_field]} ? obj.#{ops[:sum_field]} : 0); }"
    code = Mongo::Code.new(reduce_function)
    group([ops[:key]].flatten, {'a' => 'a'}, {"count" => 0},code)
  end
  def sum_by(ops)
    sum_by_raw(ops).inject({}) { |h,a| k = ops[:key]; h.merge(a[k] => a['count'])}
  end
end

