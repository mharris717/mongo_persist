class Object
  def dsl_method(name,&b)
    define_method(name) do |*args|
      if args.empty?
        res = instance_variable_get("@#{name}")
        if res.nil? && block_given?
          res = b.call
          instance_variable_set("@#{name}",res) 
        end
        res
      else
        instance_variable_set("@#{name}",args.first)
      end
    end
  end
  def dsl_class_method(name,&b)
    self.class.dsl_method(name,&b)
  end
end

class OrderedHash
  def reject(&b)
    res = OrderedHash.new
    each { |k,v| res[k] = v unless yield(k,v) }
    res
  end
end

class Object
  def sos(m)
    respond_to?(m) ? send(m) : self
  end
  def klass
    self.class
  end
end

module FromHash
  def from_hash(ops)
    ops.each do |k,v|
      send("#{k}=",v)
    end
    self
  end
  def initialize(ops={})
    from_hash(ops)
  end
end

class Hash
  def map_value
    res = {}
    each { |k,v| res[k] = yield(v) }
    res
  end
end