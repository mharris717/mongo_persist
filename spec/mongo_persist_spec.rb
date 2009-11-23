require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

def on_rcr?
  dir = File.dirname(__FILE__)
  !!(dir =~ /\/mnt\/repos/).tap { |x| puts "Dir #{dir} rcr? #{res}" }
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
end
