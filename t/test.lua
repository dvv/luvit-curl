local A = require('./assert')
--[[for k, v in pairs(A) do
  _G[k] = function (...)
    assert(v(...))
  end
end]]--

exports = {}

exports['asserts_ok'] = function(test)
  ok(true)
  test.done()
end

exports['asserts_equal'] = function(test)
  equal(1, 1)
  _not(equal(2, 1))
  equal({1,2,3, foo = 'foo', bar = { 'baz' }}, {bar = { 'baz' }, 1,2,3, foo = 'foo'})
  _not(equal({1,2,3, foo = 'foo', bar = { 'baz' }}, {bar = { 'baz' }, 1,3,2, foo = 'foo'}))
  test.done()
end

exports['asserts_nil'] = function(test)
  is_nil(nil)
  _not(is_nil(1))
  test.done()
end

exports['asserts_table'] = function(test)
  is_table({})
  is_table({1,2,3})
  is_table({a=1,b=3})
  is_table({a=1,0,2,3,b=3})
  _not(is_table(1))
  _not(is_table(false))
  _not(is_table(true))
  _not(is_table('a'))
  test.done()
end

local _g = { }
for k, v in pairs(A) do
  _g[k] = function (...)
    assert(v(...))
  end
end

-- TODO: async
local nass = 0
for k, v in pairs(exports) do
  print(k)
  setfenv(v, _g)
  v({
    done = function ()
      nass = nass + 1
      print(nass)
    end
  })
end

return exports
