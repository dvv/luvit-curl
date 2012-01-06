local get = require('../request').get

--[[
-- connect should fail gracefully
get('http://1.2.3.4', function(err, data)
  p(err, data)
  --assert(data == nil)
  --assert(err == "tcp_connect: invalid argument")
end)

-- JSON should parse ok
get('http://loginza.ru/api/authinfo?token=a88e7cec94343bae63624b569ab09da5', function(err, data)
  --p(err, data)
  assert(err == nil)
  assert(data.error_message == "Token value value was used previously.")
  assert(data.error_type == "token_validation")
end)
]]--
-- redirects
get('http://google.com', function(err, data)
  -- TODO
  assert(err == nil)
  p('GOOGLE', err, data)
end)

-- TODO: https://

-- TODO: proxy
