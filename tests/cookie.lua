local os = require('os')

local Cookie = require('../lib/cookie').Cookie

-- smoke
local smoke_tests = {
  ['foo=foo'] = {foo = {value = 'foo'}},
  ['foo='] = {foo = {value = ''}},
  ['foo=1 ; httponly'] = {foo = {value = '1', httponly = true}},
  ['foo=1 ; secure;httponly ; expires=Any, Jan 1 2013 00:00:00 GMT'] = {foo = {value = '1', httponly = true, secure = true, expires = 2000000000}},
  ['foo=2 ; secure;httponly ; max-AGE   = 100'] = {foo = {value = '2', httponly = true, secure = true, expires = os.time()+100, ['max-age'] = 100}},
  ['foo=3 ;  port   = 100 ; port = 200'] = {foo = {value = '3', port = '100'}},
  ['foo=4 ;  MaX-age=-qwe'] = {foo = {value = '4'}},
  ['foo=4 ;  MaX-age=-123'] = {foo = {value = '4'}},
  ['foo=5 ;  MaX-age'] = {foo = {}},
  -- invalid name
  ['$foo=bar '] = {},
  -- bad domain
  ['foo=6 ;  domain=domain'] = {},
  ['foo=6 ;  domain=.domain'] = {},
  ['foo=6 ;  domain=domain.'] = {},
  -- special domain
  ['foo=4 ;  domain=.local'] = {foo = {value = '4', domain = '.local'}},
  ['foo=4 ;  domain=local'] = {foo = {value = '4', domain = '.local'}},
}

-- session mode: update cookies with single Set-Cookie:
local simple_update_tests = {
  {'foo=foo', {foo = {value = 'foo'}}},
  {'foo=foo', {foo = {value = 'foo', old_value = 'foo'}}},
  {'foo=', {foo = {value = '', old_value = 'foo'}}},
  {'bar=bar', {foo = {value = '', old_value = ''}, bar = {value = 'bar'}}},
  {'foo=newfoo', {foo = {value = 'newfoo', old_value = ''}, bar = {value = 'bar', old_value = 'bar'}}},
  {'', {foo = {value = 'newfoo', old_value = 'newfoo'}, bar = {value = 'bar', old_value = 'bar'}}},
}

-- session mode: update cookies with multiple Set-Cookie:
local multi_update_tests = {
  {' foo=foo , bar=bar  ', {foo = {value = 'foo'}, bar = {value = 'bar'}}},
  {' foo=foo1 , bar=,baz=baz  ', {foo = {value = 'foo1', old_value = 'foo'}, bar = {value = '', old_value = 'bar'}, baz = {value = 'baz'}}},
  {'   ', {foo = {value = 'foo1', old_value = 'foo1'}, bar = {value = '', old_value = ''}, baz = {value = 'baz', old_value = 'baz'}}},
  {'foo=;expires=1970   ', {foo = {old_value = 'foo1'}, bar = {value = '', old_value = ''}, baz = {value = 'baz', old_value = 'baz'}}},
}

exports = { }

exports['cookie parsed'] = function (test)
  for header, expected in pairs(smoke_tests) do
    local cookie = Cookie:new()
    cookie:update(header, 'http://foo.bar.com:8080/')
    p('STATE', cookie.jar)
    test.equal(cookie.jar, expected)
  end
  test.done()
end

local function update_factory(tests)
  return function (test)
    local cookie = Cookie:new()
    for _, case in ipairs(tests) do
      cookie:update(case[1], 'http://foo.bar.com:8080/')
      test.equal(cookie.jar, case[2])
    end
    p('STATE', cookie.jar)
    test.done()
  end
end

exports['cookie updated 1'] = update_factory(simple_update_tests)
exports['cookie updated 2'] = update_factory(multi_update_tests)

return exports
