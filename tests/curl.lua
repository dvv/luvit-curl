local exports = { }

local get = require('../').get

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

exports['test JSON response should parse ok'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/json',
  proxy = false,
}, function (err, data)
  --p('JSON', err, data)
  asserts.is_nil(err)
  asserts.not_nil(data)
  asserts.dequals(data.foo, {1, 2, 3})
  asserts.equals(data.bar, 'bar')
  test.done('JSON')
end)
end

exports['test urlencoded response should parse ok'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/urlencoded',
  proxy = false,
}, function (err, data)
  --p('URLENCODED', err, data)
  asserts.is_nil(err)
  asserts.dequals(data, {foo='bar',bar='baz',f='',escaped='%5='})
  test.done('URLENCODED')
end)
end

exports['test html response should come verbatim'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/html',
  proxy = false,
}, function (err, data)
  --p('HTML', err, data)
  asserts.is_nil(err)
  asserts.dequals(data, '<html></html>')
  test.done('HTML')
end)
end

exports['test unknown-type response should come verbatim'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/fake-urlencoded',
  proxy = false,
}, function (err, data)
  --p('FAKE URLENCODED', err, data)
  asserts.is_nil(err)
  asserts.dequals(data, 'foo=bar&bar=baz&f&escaped=%255%3D')
  test.done('FAKE URLENCODED')
end)
end

exports['test redirects are ok'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/redirect',
  proxy = false,
  redirects = 10,
}, function (err, data)
  --p('REDIRECT10', err, data)
  asserts.is_nil(err)
  asserts.equals(data, 'REDIRECTED OK')
  test.done('REDIRECTED OK')
end)
end

exports['test redirects honor max hops'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/redirect',
  proxy = false,
  redirects = 3,
}, function (err, data)
  --p('REDIRECT3', err, data)
  asserts.is_nil(err)
  asserts.equals(data, 'REDIRECTED to 3rd hop')
  test.done('REDIRECTED timeout 3rd hop')
end)
end

exports['test HTTP 404 reported'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/404',
  proxy = false,
}, function (err, data)
  --p('404', err, data)
  asserts.dequals(err, { message = "Not Found", code = 404 })
  asserts.is_nil(data)
  test.done('404')
end)
end

exports['test HTTP 403 reported'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/403',
  proxy = false,
}, function (err, data)
  --p('403', err, data)
  asserts.dequals(err, { message = "Prohibited", code = 403 })
  asserts.is_nil(data)
  test.done('403')
end)
end

exports['test HTTP 500 reported'] = function (test, asserts)
get({
  url = 'http://127.0.0.1:44444/500',
  proxy = false,
}, function (err, data)
  --p('500', err, data)
  asserts.dequals(err, { message = "Server Error", code = 500 })
  asserts.is_nil(data)
  test.done('500')
end)
end

return exports
