local os = require('os')

local Cookie = require('../lib/cookie').Cookie

-- smoke
local smoke_tests = {
  ['foo=foo'] = {foo = {value = 'foo'}},
  ['foo='] = {foo = {value = ''}},
  ['foo=0 ; httponly'] = {foo = {value = '0', httponly = true}},
  ['foo=1 ; secure;httponly ; expires=Any, Jan 1 2013 00:00:00 GMT'] = {foo = {value = '1', httponly = true, secure = true, expires = 2000000000}},
  ['foo=2 ; secure;httponly ; max-AGE   = 100'] = {foo = {value = '2', httponly = true, secure = true, expires = os.time()+100, ['max-age'] = 100}},
  ['foo=3 ;  port   = 100 ; port = 200'] = {foo = {value = '3', port = '100'}},
  ['foo=4 ;  MaX-age=-qwe'] = {foo = {value = '4'}},
  ['foo=4 ;  MaX-age=-123'] = {foo = {value = '4'}},
  ['foo=5 ;  MaX-age'] = {foo = {value = '5'}},
  -- invalid name
  ['$foo=bar '] = {},
  -- good domain
  ['foo=6 ;  domain=a.b.c'] = {foo = {value = '6', domain = '.a.b.c'}},
  -- bad domain
  ['foo=7 ;  domain=.domain'] = {},
  ['foo=8 ;  domain=domain.'] = {},
  -- special domain
  ['foo=9 ;  domain=.local'] = {foo = {value = '9', domain = '.local'}},
  ['foo=10 ;  domain=local'] = {foo = {value = '10', domain = '.local'}},
}

-- domain
local domain_tests_1 = {
  -- bad domain
  ['foo=1 ;  domain=foo.bar.com'] = {foo = {value = '1', domain = '.foo.bar.com', path = '/'}},
  ['foo=2 ;  domain=bar.com'] = {foo = {value = '2', domain = '.bar.com', path = '/'}},
  ['foo=3 ;  domain=.bar.com'] = {foo = {value = '3', domain = '.bar.com', path = '/'}},
  ['foo=4 ;  domain=.'] = {},
  ['foo=5 ;  domain=com.'] = {},
  ['foo=6 ;  domain=.com.'] = {},
  ['foo=7 ;  domain=.com'] = {},
}
local domain_tests_2 = {
  [{'foo=1 ;  domain=.local', 'example'}] = {foo = {value = '1', domain = '.local', path = '/'}},
  [{'foo=2 ;  domain=.foo.com', 'y.x.foo.com'}] = {},
  [{'foo=3 ;  domain=.foo.com', 'x.foo.com/aaa/'}] = {foo = {value = '3', domain = '.foo.com', path = '/aaa/'}},
  [{'foo=4 ;  domain=ajax.com', 'ajax.com/cc/c/c'}] = {foo = {value = '4', domain = '.ajax.com', path = '/cc/c/c/'}},
}

local path_tests = {
  [{'foo=1 ; path = /', 'a.b'}] = {foo = {value = '1', domain = 'a.b', path = '/'}},
  [{'foo=2 ; path = /u', 'a.b/u'}] = {foo = {value = '2', domain = 'a.b', path = '/u'}},
  [{'foo=3 ; path = /u/v', 'a.b/u'}] = {},
  [{'foo=4 ; path = /u', 'a.b/u/v'}] = {foo = {value = '4', domain = 'a.b', path = '/u'}},
}

-- session mode: update cookies with single Set-Cookie:
local simple_update_tests = {
  {'foo=foo', {foo = {value = 'foo', domain = 'foo.bar.com', path = '/abc/'}}},
  {'foo=foo', {foo = {value = 'foo', old_value = 'foo', domain = 'foo.bar.com', path = '/abc/'}}},
  {'foo=', {foo = {value = '', old_value = 'foo', domain = 'foo.bar.com', path = '/abc/'}}},
  {'bar=bar', {foo = {value = '', old_value = '', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = 'bar', domain = 'foo.bar.com', path = '/abc/'}}},
  {'foo=newfoo', {foo = {value = 'newfoo', old_value = '', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = 'bar', old_value = 'bar', domain = 'foo.bar.com', path = '/abc/'}}},
  {'', {foo = {value = 'newfoo', old_value = 'newfoo', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = 'bar', old_value = 'bar', domain = 'foo.bar.com', path = '/abc/'}}},
}

-- session mode: update cookies with multiple Set-Cookie:
local multi_update_tests = {
  {' foo=foo , bar=bar  ', {foo = {value = 'foo', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = 'bar', domain = 'foo.bar.com', path = '/abc/'}}},
  {' foo=foo1 , bar=,baz=baz  ', {foo = {value = 'foo1', old_value = 'foo', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = '', old_value = 'bar', domain = 'foo.bar.com', path = '/abc/'}, baz = {value = 'baz', domain = 'foo.bar.com', path = '/abc/'}}},
  {'   ', {foo = {value = 'foo1', old_value = 'foo1', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = '', old_value = '', domain = 'foo.bar.com', path = '/abc/'}, baz = {value = 'baz', old_value = 'baz', domain = 'foo.bar.com', path = '/abc/'}}},
  {'foo=;expires=1970  ; ', {foo = {old_value = 'foo1', domain = 'foo.bar.com', path = '/abc/'}, bar = {value = '', old_value = '', domain = 'foo.bar.com', path = '/abc/'}, baz = {value = 'baz', old_value = 'baz', domain = 'foo.bar.com', path = '/abc/'}}},
  {'bar=;expires=1970  ; ,baz=;expires= 1971 ', {foo = {domain = 'foo.bar.com', path = '/abc/'}, bar = {old_value = '', domain = 'foo.bar.com', path = '/abc/'}, baz = {old_value = 'baz', domain = 'foo.bar.com', path = '/abc/'}}},
}

exports = { }

exports['cookie parsed'] = function (test)
  for header, expected in pairs(smoke_tests) do
    local cookie = Cookie:new()
    cookie:update(header)
    test.equal(cookie.jar, expected)
  end
  test.done()
end

exports['domain honored'] = function (test)
  for header, expected in pairs(domain_tests_1) do
    local cookie = Cookie:new()
    cookie:update(header, 'http://foo.bar.com/')
    test.equal(cookie.jar, expected)
  end
  test.done()
end

exports['domain honored, custom request-uri'] = function (test)
  for header, expected in pairs(domain_tests_2) do
    local cookie = Cookie:new()
    cookie:update(header[1], header[2])
    test.equal(cookie.jar, expected)
  end
  test.done()
end

exports['path honored'] = function (test)
  for header, expected in pairs(path_tests) do
    local cookie = Cookie:new()
    cookie:update(header[1], header[2])
    test.equal(cookie.jar, expected)
  end
  test.done()
end

local function update_factory(tests)
  return function (test)
    local cookie = Cookie:new()
    for _, case in ipairs(tests) do
      cookie:update(case[1], 'http://foo.bar.com:8080/abc')
      test.equal(cookie.jar, case[2])
    end
    --p('STATE', cookie.jar)
    test.done()
  end
end

exports['cookie updated 1'] = update_factory(simple_update_tests)
exports['cookie updated 2'] = update_factory(multi_update_tests)

exports['cookie stringifies well'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1,bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1;bar=2')
  cookie:update('foo=3,bar=2', 'a.b.c/d/e')
  test.equal(cookie:serialize('a.b.c/d/e'), 'foo=3;bar=2')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=3;bar=2')
  -- nothing, since domain is a.b.c
  test.equal(cookie:serialize('b.c/d'), '')
  test.equal(cookie:serialize('q.a.b.c/d'), '')
  ---
  local cookie = Cookie:new()
  cookie:update('foo=1;domain=b.c,bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('b.c/d'), 'foo=1')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1;bar=2')
  test.equal(cookie:serialize('q.a.b.c/d'), '')
  test.done()
end

exports['login example?'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1', 'a.b.c/d/login')
  cookie:update('bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1;bar=2')
  test.equal(cookie:serialize('a.b.c/d/login'), 'foo=1')
  test.equal(cookie:serialize('a.b.c/e'), '')
  test.done()
end

exports['assertions ok'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1', 'a.b.c/d/')
  test.ok(cookie:is_set('foo'))
  test.not_ok(cookie:is_updated('foo'))
  test.not_ok(cookie:is_same('foo'))
  cookie:update('foo=2', 'a.b.c/d/')
  test.not_ok(cookie:is_set('foo'))
  test.ok(cookie:is_updated('foo'))
  test.not_ok(cookie:is_same('foo'))
  cookie:update('foo=2', 'a.b.c/d/')
  test.not_ok(cookie:is_set('foo'))
  test.not_ok(cookie:is_updated('foo'))
  test.ok(cookie:is_same('foo'))
  test.done()
end

return exports
