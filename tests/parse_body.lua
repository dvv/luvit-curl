require('helper')

local parse_body = require('../').parse
local get = require('../').get

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
  ['<html><body></body></html>'] = '<html><body></body></html>',
}

for input, output in pairs(tests) do
  local tokens = parse_body(input)
  if not deep_equal(output, tokens) then
    p("Expected", output)
    p("But got", tokens)
    error("Test failed " .. input)
  end
end
