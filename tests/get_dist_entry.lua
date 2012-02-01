local get = require('../').get

exports = { }

exports['github is accessed ok'] = function (test)
  get({
    url = 'http://nodeload.github.com/luvit/luvit/zipball/0.1.5',
  }, function (err, data)
    --p('GOT', err, #data)
    test.is_nil(err)
    test.is_string(data)
    test.equal(#data, 835435)
    local buf = require('buffer'):new(data)
    test.equal(buf[1], 0x50)
    test.equal(buf[2], 0x4B)
    test.equal(buf[3], 0x03)
    test.equal(buf[4], 0x04)
    test.done()
  end)
end

return exports
