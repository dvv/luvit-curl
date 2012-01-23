local get = require('../').get

exports = { }

exports['JSON response should parse ok'] = function (test)
  get({
    url = 'http://twitter.com/status/user_timeline/creationix.json?count=2&callback=foo',
  }, function (err, data)
    --p('JSON', err, data)
    test.is_nil(err)
    test.ok(type(data) == 'table')
    test.is_number(data[1].id)
    test.done()
  end)
end

return exports
