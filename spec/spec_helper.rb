$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'mongo_persist'
require 'spec'
require 'spec/autorun'

Spec::Runner.configure do |config|
  config.mock_with :rr
end

def require_lib(path,name=nil)
  name ||= path.split("/")[-1]
  file = "#{path}.rb"
  if FileTest.exists?(file)
    require path
  else
    require name
  end
end