local exports = { }

local get = require('../').get
local post = require('../').post
local parse_request = require('../').parse_request

-- create a helper server
require('http').createServer('127.0.0.1', 44444, function (req, res)
  if req.url == '/ok' then
    res:finish('OK')
  elseif req.url == '/json' then
    res:finish('{"foo": [1, 2, 3], "bar": "bar"}')
  elseif req.url == '/urlencoded' then
    res:writeHead(200, {['Content-Type'] = 'application/www-urlencoded; charset=UTF-8'})
    res:finish('foo=bar&bar=baz&f&escaped=%255%3D')
  elseif req.url == '/fake-urlencoded' then
    res:finish('foo=bar&bar=baz&f&escaped=%255%3D')
  elseif req.url == '/html' then
    res:finish('<html></html>')
  elseif req.url == '/redirect' then
    res:writeHead(301, {Location = '/redirect1'})
    res:finish()
  elseif req.url == '/redirect1' then
    res:writeHead(302, {Location = '/redirect2'})
    res:finish()
  elseif req.url == '/redirect2' then
    res:writeHead(303, {Location = '/redirect3'})
    res:finish()
  elseif req.url == '/redirect3' then
    res:writeHead(307, {Location = '/redirect4'})
    res:finish('REDIRECTED to 3rd hop')
  elseif req.url == '/redirect4' then
    res:finish('REDIRECTED OK')
  elseif req.url == '/404' then
    res:writeHead(404, {})
    res:finish('Not Found')
  elseif req.url == '/403' then
    res:writeHead(403, {})
    res:finish('Prohibited')
  elseif req.url == '/500' then
    res:writeHead(500, {})
    res:finish('Server Error')
  elseif req.url == '/echo' then
    res:writeHead(200, {})
    parse_request(req, function (err, data)
      p('INC', data)
      res:finish(err or data)
    end)
  else
    res:writeHead(404, {})
    res:finish('Not Found')
  end
end)

-- FIXME: should have timeout
exports['test connect should fail gracefully'] = function (test)
get({
  url = 'http://127.0.0.1:44443',
  proxy = false,
}, function (err, data)
  --p(err, data)
  test.is_nil(data)
  test.equal(err.code, 'ECONNREFUSED')
  test.done()
end)
end

exports['test JSON response should parse ok'] = function (test)
get({
  url = 'http://127.0.0.1:44444/json',
  proxy = false,
}, function (err, data)
  --p('JSON', err, data)
  test.is_nil(err)
  test.not_is_nil(data)
  test.equal(data.foo, {1, 2, 3})
  test.equal(data.bar, 'bar')
  test.done()
end)
end

exports['test urlencoded response should parse ok'] = function (test)
get({
  url = 'http://127.0.0.1:44444/urlencoded',
  proxy = false,
}, function (err, data)
  --p('URLENCODED', err, data)
  test.is_nil(err)
  test.equal(data, {foo='bar',bar='baz',f='',escaped='%5='})
  test.done()
end)
end

exports['test html response should come verbatim'] = function (test)
get({
  url = 'http://127.0.0.1:44444/html',
  proxy = false,
}, function (err, data)
  --p('HTML', err, data)
  test.is_nil(err)
  test.equal(data, '<html></html>')
  test.done()
end)
end

exports['test unknown-type response should come verbatim'] = function (test)
get({
  url = 'http://127.0.0.1:44444/fake-urlencoded',
  proxy = false,
}, function (err, data)
  --p('FAKE URLENCODED', err, data)
  test.is_nil(err)
  test.equal(data, 'foo=bar&bar=baz&f&escaped=%255%3D')
  test.done()
end)
end

exports['test redirects are ok'] = function (test)
get({
  url = 'http://127.0.0.1:44444/redirect',
  proxy = false,
  redirects = 10,
}, function (err, data)
  --p('REDIRECT10', err, data)
  test.is_nil(err)
  test.equal(data, 'REDIRECTED OK')
  test.done()
end)
end

exports['test redirects honor max hops'] = function (test)
get({
  url = 'http://127.0.0.1:44444/redirect',
  proxy = false,
  redirects = 3,
}, function (err, data)
  --p('REDIRECT3', err, data)
  test.is_nil(err)
  test.equal(data, 'REDIRECTED to 3rd hop')
  test.done()
end)
end

exports['test HTTP 404 reported'] = function (test)
get({
  url = 'http://127.0.0.1:44444/404',
  proxy = false,
}, function (err, data)
  --p('404', err, data)
  --test.equal(err, { message = "Not Found", code = 404 })
  test.equal(err.code, 404)
  test.is_nil(data)
  test.done()
end)
end

exports['test HTTP 403 reported'] = function (test)
get({
  url = 'http://127.0.0.1:44444/403',
  proxy = false,
}, function (err, data)
  --p('403', err, data)
  test.equal(err.code, 403)
  test.is_nil(data)
  test.done()
end)
end

exports['test HTTP 500 reported'] = function (test)
get({
  url = 'http://127.0.0.1:44444/500',
  proxy = false,
}, function (err, data)
  --p('500', err, data)
  test.equal(err.code, 500)
  test.is_nil(data)
  test.done()
end)
end

exports['HTTP echoes back'] = function (test)
post({
  url = 'http://127.0.0.1:44444/echo',
  proxy = false,
  headers = {
    ['Content-Length'] = 3,
  },
}, 'foo', function (err, data)
  p('echo', err, data)
  test.is_nil(err)
  test.equal(data, 'foo')
  test.done()
end)
end

return exports
