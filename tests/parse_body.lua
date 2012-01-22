
local parse_body = require('../').parse

-- Basic code coverage
local tests = {
  [{'%25 %20+=foo%25%00%41bar&a=%26%3db','application/www-urlencoded'}] = {['%   '] = 'foo%\000Abar', a = '&=b'},
  [{' {%25 %20+=foo%25%00%41bar&a=%26%3db','application/www-urlencoded'}] = {[' {%   '] = 'foo%\000Abar', a = '&=b'},
  ['{%25 %20+=foo%25%00%41bar&a=%26%3db'] = '{%25 %20+=foo%25%00%41bar&a=%26%3db',
  ['{foo: bar}'] = '{foo: bar}',
  ['{"foo": "bar"}'] = {foo = 'bar'},
  ['{"foo": "bar}'] = '{"foo": "bar}',
  ['[1]'] = {1},
  ['[a]'] = '[a]',
  ['<html><body></body></html>'] = '<html><body></body></html>',
  [{'foo([1,2,3]);','application/javascript'}] = {1,2,3},
}

exports = { }

local n = 1
for input, output in pairs(tests) do
  local str, ctype
  if type(input) == 'table' then
    str = input[1]
    ctype = input[2]
  else
    str = input
  end
  exports['test ' .. str] = function (test)
    local tokens = parse_body(str, ctype)
    test.equal(output, tokens)
    test.done()
  end
  n = n + 1
end

return exports
