local get = require('../').get

--[[process:on('error', function (err)
  debug('CAUGHT', err)
end)]]--

-- JSON response should parse ok
get({
  url = 'http://twitter.com/status/user_timeline/creationix.json?count=1&callback=foo',
}, function (err, data)
  p(err, data)
  --assert(err == nil)
  --local json = JSON.parse(data:sub(5, -3))
  --p('JSON', json)
end)
