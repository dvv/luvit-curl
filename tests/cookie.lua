local os = require('os')

local Cookie = require('../lib/cookie').Cookie

-- smoke
local smoke_tests = {
  ['foo=foo'] = {{name = 'foo', value = 'foo'}},
  ['foo='] = {{name = 'foo', value = ''}},
  ['foo=0 ; httponly'] = {{name = 'foo', value = '0', httponly = true}},
  ['foo=1 ; secure;httponly ; expires=Any, Jan 1 2013 00:00:00 GMT'] = {{name = 'foo', value = '1', httponly = true, secure = true, expires = 2000000000}},
  ['foo=2 ; secure;httponly ; max-AGE   = 100'] = {{name = 'foo', value = '2', httponly = true, secure = true, expires = os.time()+100 }},
  ['foo=3 ;  port   = 100 ; port = 200'] = {{name = 'foo', value = '3'}},
  ['foo=4 ;  MaX-age=-qwe'] = {{name = 'foo', value = '4'}},
  ['foo=5 ;  MaX-age=-123'] = {{name = 'foo'}},
  ['foo=6 ;  MaX-age'] = {{name = 'foo', value = '6'}},
  -- good domain
  ['foo=6 ;  domain=a.b.c'] = {{name = 'foo', value = '6', domain = 'a.b.c'}},
  -- bad domain
  ['foo=7 ;  domain=.domain'] = {},
  ['foo=8 ;  domain=domain.'] = {},
}

-- domain
local domain_tests_1 = {
  -- bad domain
  ['foo=1 ;  domain=foo.bar.com'] = {{name = 'foo', value = '1', domain = 'foo.bar.com', path = '/'}},
  ['foo=2 ;  domain=bar.com'] = {{name = 'foo', value = '2', domain = 'bar.com', path = '/'}},
  ['foo=3 ;  domain=.bar.com'] = {{name = 'foo', value = '3', domain = 'bar.com', path = '/'}},
  ['foo=4 ;  domain=.'] = {},
  ['foo=5 ;  domain=com.'] = {},
  ['foo=6 ;  domain=.com.'] = {},
  ['foo=7 ;  domain=.com'] = {},
}
local domain_tests_2 = {
  [{'foo=1 ;  domain=.local', 'example.local'}] = {},
  [{'foo=2 ;  domain=.foo.com', 'y.x.foo.com'}] = {},
  [{'foo=3 ;  domain=.foo.com', 'x.foo.com/aaa/'}] = {{name = 'foo', value = '3', domain = 'foo.com', path = '/aaa'}},
  [{'foo=4 ;  domain=ajax.com', 'ajax.com/cc/c/c'}] = {{name = 'foo', value = '4', domain = 'ajax.com', path = '/cc/c'}},
}

local path_tests = {
  [{'foo=1 ; path = /', 'a.b'}] = {{name = 'foo', value = '1', domain = 'a.b', path = '/'}},
  [{'foo=2 ; path = /u', 'a.b/u'}] = {{name = 'foo', value = '2', domain = 'a.b', path = '/u'}},
  [{'foo=3 ; path = /u/v', 'a.b/u'}] = {{name = 'foo', value = '3', domain = 'a.b', path = '/u/v'}},
  [{'foo=4 ; path = /u', 'a.b/u/v'}] = {{name = 'foo', value = '4', domain = 'a.b', path = '/u'}},
  [{'foo=5 ; path = /uu', 'a.b/u/v'}] = {{name = 'foo', value = '5', domain = 'a.b', path = '/uu'}},
  [{'foo=6 ; path = /u', 'a.b/uu/v'}] = {{name = 'foo', value = '6', domain = 'a.b', path = '/u'}},
}

-- session mode: update cookies with single Set-Cookie:
local simple_update_tests = {
  {'foo=foo', {{name = 'foo', value = 'foo', domain = 'foo.bar.com', path = '/abc'}}},
  {'foo=foo', {{name = 'foo', value = 'foo', old_value = 'foo', domain = 'foo.bar.com', path = '/abc'}}},
  {'foo=', {{name = 'foo', value = '', old_value = 'foo', domain = 'foo.bar.com', path = '/abc'}}},
  {'bar=bar', {{name = 'foo', value = '', old_value = '', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = 'bar', domain = 'foo.bar.com', path = '/abc'}}},
  {'foo=newfoo', {{name = 'foo', value = 'newfoo', old_value = '', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = 'bar', old_value = 'bar', domain = 'foo.bar.com', path = '/abc'}}},
  {'', {{name = 'foo', value = 'newfoo', old_value = 'newfoo', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = 'bar', old_value = 'bar', domain = 'foo.bar.com', path = '/abc'}}},
}

-- session mode: update cookies with multiple Set-Cookie:
local multi_update_tests = {
  {' foo=foo , bar=bar  ', {{name = 'foo', value = 'foo', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = 'bar', domain = 'foo.bar.com', path = '/abc'}}},
  {' foo=foo1 , bar=,baz=baz  ', {{name = 'foo', value = 'foo1', old_value = 'foo', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = '', old_value = 'bar', domain = 'foo.bar.com', path = '/abc'}, {name = 'baz', value = 'baz', domain = 'foo.bar.com', path = '/abc'}}},
  {'   ', {{name = 'foo', value = 'foo1', old_value = 'foo1', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = '', old_value = '', domain = 'foo.bar.com', path = '/abc'}, {name = 'baz', value = 'baz', old_value = 'baz', domain = 'foo.bar.com', path = '/abc'}}},
  {'foo=;expires=1970  ; ', {{name = 'foo', old_value = 'foo1', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', value = '', old_value = '', domain = 'foo.bar.com', path = '/abc'}, {name = 'baz', value = 'baz', old_value = 'baz', domain = 'foo.bar.com', path = '/abc'}}},
  {'bar=;expires=1970  ; ,baz=;expires= 1971 ', {{name = 'foo', domain = 'foo.bar.com', path = '/abc'}, {name = 'bar', old_value = '', domain = 'foo.bar.com', path = '/abc'}, {name = 'baz', old_value = 'baz', domain = 'foo.bar.com', path = '/abc'}}},
}

-- session mode: update cookies with multiple Set-Cookie:, different domains
local multi_update_domain_tests = {
  {' foo=foo , bar=bar  ', {
    {name = 'foo', value = 'foo', domain = 'foo.bar.com', path = '/abc'},
    {name = 'bar', value = 'bar', domain = 'foo.bar.com', path = '/abc'},
  }},
  {' foo=foo1 , bar=,baz=baz2;domain=bar.com  ', {
    {name = 'foo', value = 'foo1', old_value = 'foo', domain = 'foo.bar.com', path = '/abc'},
    {name = 'bar', value = '', old_value = 'bar', domain = 'foo.bar.com', path = '/abc'},
    {name = 'baz', value = 'baz2', domain = 'bar.com', path = '/abc'},
  }},
  {'foo=;expires=1970  , baz=baz2', {
    {name = 'foo', old_value = 'foo1', domain = 'foo.bar.com', path = '/abc'},
    {name = 'bar', value = '', old_value = '', domain = 'foo.bar.com', path = '/abc'},
    {name = 'baz', value = 'baz2', old_value = 'baz2', domain = 'bar.com', path = '/abc'},
    {name = 'baz', value = 'baz2', domain = 'foo.bar.com', path = '/abc'},
  }},
}

local function update_factory(tests)
  return function (test)
    local cookie = Cookie:new()
    for _, case in ipairs(tests) do
      cookie:update(case[1], 'http://foo.bar.com/abc/')
      --p('COOK', cookie.jar)
      test.equal(cookie.jar, case[2])
    end
    test.done()
  end
end

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

exports['cookie updated 1'] = update_factory(simple_update_tests)
exports['cookie updated 2'] = update_factory(multi_update_tests)
exports['cookie updated 3'] = update_factory(multi_update_domain_tests)

exports['cookie stringifies well'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1,bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1; bar=2')
  cookie:update('foo=3,bar=2', 'a.b.c/d/e')
  test.equal(cookie:serialize('a.b.c/d/e'), 'foo=3; bar=2; foo=1; bar=2')
  test.equal(cookie:serialize('a.b.c/d/f'), 'foo=3; bar=2; foo=1; bar=2')
  test.equal(cookie:serialize('a.b.c/'), 'foo=1; bar=2')
  test.equal(cookie:serialize('b.c/d'), '')
  test.equal(cookie:serialize('a.b.c/f'), 'foo=1; bar=2')
  test.equal(cookie:serialize('q.a.b.c/d'), 'foo=3; bar=2; foo=1; bar=2')
  cookie:update('foo=4,bar=4', 'a.b.c/d/e/')
  test.equal(cookie:serialize('q.a.b.c/d/e'), 'foo=4; bar=4; foo=3; bar=2; foo=1; bar=2')
  ---
  local cookie = Cookie:new()
  cookie:update('foo=1;domain=b.c,bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('b.c/d'), 'foo=1')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1; bar=2')
  test.equal(cookie:serialize('q.a.b.c/d'), 'bar=2')
  ---
  local cookie = Cookie:new()
  cookie:update('foo=1;domain=b.c,foo=2;path=/d/e/f', 'a.b.c/d')
  test.equal(cookie:serialize('b.c/d'), 'foo=1')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1')
  test.equal(cookie:serialize('a.b.c/d/e/f'), 'foo=2; foo=1')
  test.equal(cookie:serialize('q.a.b.c/d'), '')
  test.done()
end

exports['login example?'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1', 'a.b.c/d/login')
  cookie:update('bar=2', 'a.b.c/d')
  test.equal(cookie:serialize('a.b.c/d'), 'foo=1; bar=2')
  test.equal(cookie:serialize('a.b.c/d/login'), 'foo=1; bar=2')
  test.equal(cookie:serialize('a.b.c/e'), 'bar=2')
  test.done()
end

exports['assertions ok'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1', 'a.b.c/d/')
  test.ok(cookie:is_set('foo', 'a.b.c', '/d'))
  test.not_ok(cookie:is_updated('foo', 'a.b.c', '/d'))
  test.not_ok(cookie:is_same('foo', 'a.b.c', '/d'))
  cookie:update('foo=2', 'a.b.c/d/')
  test.not_ok(cookie:is_set('foo', 'a.b.c', '/d'))
  test.ok(cookie:is_updated('foo', 'a.b.c', '/d'))
  test.not_ok(cookie:is_same('foo', 'a.b.c', '/d'))
  cookie:update('foo=2', 'a.b.c/d/')
  test.not_ok(cookie:is_set('foo', 'a.b.c', '/d'))
  test.not_ok(cookie:is_updated('foo', 'a.b.c', '/d'))
  test.ok(cookie:is_same('foo', 'a.b.c', '/d'))
  test.done()
end

exports['domain ok'] = function (test)
  local cookie = Cookie:new()
  cookie:update('foo=1;domain=b.c', 'a.b.c/')
  test.equal(cookie.jar, {{name = 'foo', value = '1', domain = 'b.c', path = '/'}})
  cookie:update('foo=1;domain=a.b.c', 'a.b.c/')
  test.equal(cookie.jar, {
    {name = 'foo', value = '1', old_value = '1', domain = 'b.c', path = '/'},
    {name = 'foo', value = '1', domain = 'a.b.c', path = '/'},
  })
  -- noop
  cookie:update('foo=1;domain=e.b.c', 'a.b.c/')
  test.equal(cookie.jar, {
    {name = 'foo', value = '1', old_value = '1', domain = 'b.c', path = '/'},
    {name = 'foo', value = '1', old_value = '1', domain = 'a.b.c', path = '/'},
  })
  -- noop
  cookie:update('foo=1;domain=e.f.b.c', 'a.b.c/')
  test.equal(cookie.jar, {
    {name = 'foo', value = '1', old_value = '1', domain = 'b.c', path = '/'},
    {name = 'foo', value = '1', old_value = '1', domain = 'a.b.c', path = '/'},
  })
  ---
  local cookie = Cookie:new()
  cookie:update('foo=1;domain=e.b.c', 'a.b.c/')
  test.equal(cookie.jar, {})
  cookie:update('foo=1;domain=e.f.b.c', 'a.b.c/')
  test.equal(cookie.jar, {})
  test.done()
end

return exports
