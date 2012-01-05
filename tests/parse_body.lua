local parse_body = require('../request').parse
local get = require('../request').get

-- Basic code coverage
local tests = {
  ['%25 %20+=foo%25%00%41bar&a=%26%3db'] = {['%   '] = 'foo%\000Abar', a = '&=b'},
  [' {%25 %20+=foo%25%00%41bar&a=%26%3db'] = {[' {%   '] = 'foo%\000Abar', a = '&=b'},
  ['{%25 %20+=foo%25%00%41bar&a=%26%3db'] = '{%25 %20+=foo%25%00%41bar&a=%26%3db',
  ['{foo: bar}'] = '{foo: bar}',
  ['{"foo": "bar"}'] = {foo = 'bar'},
  ['{"foo": "bar}'] = '{"foo": "bar}',
  ['[1]'] = {1},
  ['[a]'] = '[a]',
}

local equal = function(a, b)
  return a == b
end

function deep_equal(expected, actual)
  if type(expected) == 'table' and type(actual) == 'table' then
    if #expected ~= #actual then return false end
    for k, v in pairs(expected) do
      if v ~= actual[k] then return false end
    end
    return true
  else
    return equal(expected, actual)
  end
end

for input, output in pairs(tests) do
  local tokens = parse_body(input)
  if not deep_equal(output, tokens) then
    p("Expected", output)
    p("But got", tokens)
    error("Test failed " .. input)
  end
end
