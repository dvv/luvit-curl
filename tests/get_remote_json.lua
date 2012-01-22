local get = require('../').get

exports = { }

exports['JSON response should parse ok'] = function (test)
  get({
    url = 'http://twitter.com/status/user_timeline/creationix.json?count=2&callback=foo',
  }, function (err, data)
    --p(err, data)
    test.is_nil(err)
    test.ok(type(data) == 'table')
    test.equal(#data, 2)
    test.done()
  end)
end

return exports
