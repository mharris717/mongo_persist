require "mongo_scope"
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
  def mongo_attributes
    ["order_products","po_number","some_hash"]
  end
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

[Order,Product].each { |x| x.collection.remove }

o = Order.new(:po_number => 1, :some_hash => {'1' => Product.new(:name => 'Chair')})
puts o.inspect
o.mongo.save!
o = Order.collection.find_one_object(:po_number => 1)
puts o.inspect


