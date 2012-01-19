local get = require('../').get

_G.equal = function(a, b)
  return a == b
end

_G.deep_equal = function(expected, actual)
  if type(expected) == 'table' and type(actual) == 'table' then
    if #expected ~= #actual then return false end
    for k, v in pairs(expected) do
      if not deep_equal(v, actual[k]) then return false end
    end
    return true
  else
    return equal(expected, actual)
  end
end

-- create a helper server
require('http').create_server('127.0.0.1', 44444, function (req, res)
  if req.url == '/ok' then
    res:finish('OK')
  elseif req.url == '/json' then
    res:finish('{"foo": [1, 2, 3], "bar": "bar"}')
  elseif req.url == '/urlencoded' then
    res:write_head(200, {['Content-Type'] = 'application/www-urlencoded; charset=UTF-8'})
    res:finish('foo=bar&bar=baz&f&escaped=%255%3D')
  elseif req.url == '/fake-urlencoded' then
    res:finish('foo=bar&bar=baz&f&escaped=%255%3D')
  elseif req.url == '/html' then
    res:finish('<html></html>')
  elseif req.url == '/redirect' then
    res:write_head(301, {Location = '/redirect1'})
    res:finish()
  elseif req.url == '/redirect1' then
    res:write_head(302, {Location = '/redirect2'})
    res:finish()
  elseif req.url == '/redirect2' then
    res:write_head(303, {Location = '/redirect3'})
    res:finish()
  elseif req.url == '/redirect3' then
    res:write_head(307, {Location = '/redirect4'})
    res:finish('REDIRECTED to 3rd hop')
  elseif req.url == '/redirect4' then
    res:finish('REDIRECTED OK')
  elseif req.url == '/404' then
    res:write_head(404, {})
    res:finish('Not Found')
  elseif req.url == '/403' then
    res:write_head(403, {})
    res:finish('Prohibited')
  elseif req.url == '/500' then
    res:write_head(500, {})
    res:finish('Server Error')
  else
    res:write_head(404, {})
    res:finish('Not Found')
  end
end)

local tests = 9
local asserts = 0
local function done(test)
  print(test, ':', 'PASS')
  asserts = asserts + 1
  if asserts == tests then
    process.exit(0)
  end
end

--[[
-- connect should fail gracefully
-- FIXME: should have timeout
get({
  url = 'http://127.0.0.1:44443'
}, function (err, data)
  --p(err, data)
  assert(data == nil)
  assert(err == "tcp_connect: invalid argument")
end)
]]--

--p('Starting tests')

-- JSON response should parse ok
get({
  url = 'http://127.0.0.1:44444/json',
}, function (err, data)
  p('JSON', err, data)
  assert(err == nil)
  assert(deep_equal(data.foo, {1, 2, 3}))
  assert(data.bar == 'bar')
  done('JSON')
end)

-- urlencoded response should parse ok
get({
  url = 'http://127.0.0.1:44444/urlencoded',
}, function (err, data)
  --p('URLENCODED', err, data)
  assert(err == nil)
  assert(deep_equal(data, {foo='bar',bar='baz',f='',escaped='%5='}))
  done('URLENCODED')
end)

-- html response should come verbatim
get({
  url = 'http://127.0.0.1:44444/html',
}, function (err, data)
  --p('HTML', err, data)
  assert(err == nil)
  assert(deep_equal(data, '<html></html>'))
  done('HTML')
end)

-- unknown-type response should come verbatim
get({
  url = 'http://127.0.0.1:44444/fake-urlencoded',
}, function (err, data)
  --p('FAKE URLENCODED', err, data)
  assert(err == nil)
  assert(deep_equal(data, 'foo=bar&bar=baz&f&escaped=%255%3D'))
  done('FAKE URLENCODED')
end)

-- redirects are ok
get({
  url = 'http://127.0.0.1:44444/redirect',
  redirects = 10,
}, function (err, data)
  --p('REDIRECT10', err, data)
  assert(err == nil)
  assert(data == 'REDIRECTED OK')
  done('REDIRECTED OK')
end)

-- redirects are ok
get({
  url = 'http://127.0.0.1:44444/redirect',
  redirects = 3,
}, function (err, data)
  p('REDIRECT3', err, data)
  assert(err == nil)
  assert(data == 'REDIRECTED to 3rd hop')
  done('REDIRECTED timeout 3rd hop')
end)

-- HTTP statuses are reported
get({
  url = 'http://127.0.0.1:44444/404',
}, function (err, data)
  --p('404', err, data)
  assert(deep_equal(err, { message = "Not Found", code = 404 }))
  assert(data == nil)
  done('404')
end)

-- HTTP statuses are reported
get({
  url = 'http://127.0.0.1:44444/403',
}, function (err, data)
  --p('403', err, data)
  assert(deep_equal(err, { message = "Prohibited", code = 403 }))
  assert(data == nil)
  done('403')
end)

-- HTTP statuses are reported
get({
  url = 'http://127.0.0.1:44444/500',
}, function (err, data)
  --p('500', err, data)
  assert(deep_equal(err, { message = "Server Error", code = 500 }))
  assert(data == nil)
  done('500')
end)
