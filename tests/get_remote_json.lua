local get = require('../').get

exports = { }

exports['test JSON response should parse ok'] = function (test, asserts)
  get({
    url = 'http://twitter.com/status/user_timeline/creationix.json?count=2&callback=foo',
  }, function (err, data)
    --p(err, data)
    asserts.is_nil(err)
    asserts.ok(type(data) == 'table')
    asserts.equals(#data, 2)
    test.done()
  end)
end

return exports
