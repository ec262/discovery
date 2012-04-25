# Very basic Rack middleware that converts everything to JSON.
# Basically, it lets us respond from Sinatra with straight Ruby instead of
# tediously calling "to_json" every time.
class JSONResponder
  # Adapted from https://github.com/Burgestrand/rack-json/blob/master/lib/rack/json.rb
  def initialize(app)
    @app = app
  end
  
  def call(env)
    status, headers, response = @app.call(env)
    json_response = [response].flatten.map(&:to_json)
    headers["Content-Type"] = 'application/json;charset=utf-8'
    headers['Content-Length'] = json_response.inject(0) { |len, part| len + part.bytesize }.to_s
    [status, headers, json_response]
  end
end
