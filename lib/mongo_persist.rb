require 'rubygems'
require 'mongo'
require 'active_support'
require 'fattr'
%w(util core_ext array_ext hash_ext base mongo_ext).each { |x| load File.dirname(__FILE__) + "/mongo_persist/#{x}.rb" }
require 'andand'

class String
  def pluralize
    "#{self}s"
  end
end

