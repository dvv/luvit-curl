if process.env.DEBUG == '1' then
  _G.d = function(...)
    return debug('DEBUG', ...)
  end
else
  _G.d = function() end
end

local String = require('string')
local sub, find, match, gsub, gmatch, byte, char, format = String.sub, String.find, String.match, String.gsub, String.gmatch, String.byte, String.char, String.format

String.replace = gsub

local function trim(str, what)
  if what == nil then
    what = '%s+'
  end
  str = gsub(str, '^' .. what, '')
  str = gsub(str, what .. '$', '')
  return str
end
String.trim = trim

String.interpolate = function(self, data)
  if not data then
    return self
  end
  if type(data) == 'table' then
    if data[1] then
      return format(self, unpack(b))
    end
    return gsub(self, '(#%b{})', function(w)
      local var = trim(sub(w, 3, -2))
      local n, def = match(var, '([^|]-)|(.*)')
      if n then
        var = n
      end
      local s = type(data[var]) == 'function' and data[var]() or data[var] or def or w
      return s
    end)
  else
    return format(self, data)
  end
end

String.tohex = function(str)
  return (gsub(str, '(.)', function(c)
    return format('%02x', byte(c))
  end))
end

String.fromhex = function(str)
  return (gsub(str, '(%x%x)', function(h)
    local n = tonumber(h, 16)
    if n ~= 0 then
      return format('%c', n)
    else
      return '\000'
    end
  end))
end

local base64_table = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
String.base64 = function(data)
  return ((gsub(data, '.', function(x)
    local r, b = '', byte(x)
    for i = 8, 1, -1 do
      r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then
      return ''
    end
    local c = 0
    for i = 1, 6 do
      c = c + (sub(x, i, i) == '1' and 2 ^ (6 - i) or 0)
    end
    return sub(base64_table, c + 1, c + 1)
  end) .. ({
    '',
    '==',
    '='
  })[#data % 3 + 1])
end

String.escape = function(str)
  return gsub(str, '<', '&lt;'):gsub('>', '&gt;'):gsub('"', '&quot;')
end

String.unescape = function(str)
  -- TODO
  return str
end

String.split = function(str, sep, nmax)
  if sep == nil then
    sep = '%s+'
  end
  local r = { }
  if #str <= 0 then
    return r
  end
  local plain = false
  nmax = nmax or -1
  local nf = 1
  local ns = 1
  local nfr, nl = find(str, sep, ns, plain)
  while nfr and nmax ~= 0 do
    r[nf] = sub(str, ns, nfr - 1)
    nf = nf + 1
    ns = nl + 1
    nmax = nmax - 1
    nfr, nl = find(str, sep, ns, plain)
  end
  r[nf] = sub(str, ns)
  return r
end

local T = require('table')

_G.copy = function(obj)
  if type(obj) ~= 'table' then
    return obj
  end
  local x = { }
  setmetatable(x, {
    __index = obj
  })
  return x
end

_G.clone = function(obj)
  local copied = { }
  local new = { }
  copied[obj] = new
  for k, v in pairs(obj) do
    if type(v) ~= 'table' then
      new[k] = v
    elseif copied[v] then
      new[k] = copied[v]
    else
      copied[v] = clone(v, copied)
      new[k] = setmetatable(copied[v], getmetatable(v))
    end
  end
  setmetatable(new, getmetatable(u))
  return new
end

_G.extend = function(obj, with_obj)
  for k, v in pairs(with_obj) do
    obj[k] = v
  end
  return obj
end

_G.extend_unless = function(obj, with_obj)
  for k, v in pairs(with_obj) do
    if obj[k] == nil then
      obj[k] = v
    end
  end
  return obj
end

_G.push = function(t, x)
  return T.insert(t, x)
end

_G.unshift = function(t, x)
  return T.insert(t, 1, x)
end

_G.pop = function(t)
  return T.remove(t)
end

_G.shift = function(t)
  return T.remove(t, 1)
end

-- N.B. 0-based start/stop
_G.slice = function(t, start, stop)
  if start == nil then
    start = 0
  end
  if stop == nil then
    stop = #t
  end
  if start < 0 then
    start = start + #t
  end
  if stop < 0 then
    stop = stop + #t
  end
  if type(t) == 'string' then
    return sub(t, start + 1, stop)
  end
  local r = { }
  local n = 0
  local i = 0
  for i = start + 1, stop do
    n = n + 1
    r[n] = t[i]
  end
  return r
end

_G.sort = function(t, f)
  return T.sort(t, f)
end

_G.join = function(t, s)
  if s == nil then
    s = ','
  end
  return T.concat(t, s)
end

_G.has = function(t, s)
  return rawget(t, s) ~= nil
end

_G.keys = function(t)
  local r = { }
  local n = 0
  for k, v in pairs(t) do
    n = n + 1
    r[n] = k
  end
  return r
end

_G.values = function(t)
  local r = { }
  local n = 0
  for k, v in pairs(t) do
    n = n + 1
    r[n] = v
  end
  return r
end

_G.map = function(t, f)
  local r = { }
  for k, v in pairs(t) do
    r[k] = f(v, k, t)
  end
  return r
end

_G.filter = function(t, f)
  local r = { }
  for k, v in pairs(t) do
    if f(v, k, t) then
      r[k] = v
    end
  end
  return r
end

_G.each = function(t, f)
  for k, v in pairs(t) do
    f(v, k, t)
  end
end

_G.curry = function(f, g)
  return function(...)
    return f(g(unpack(arg)))
  end
end

_G.indexOf = function(t, x)
  if type(t) == 'string' then
    return find(t, x, true)
  end
  for k, v in pairs(t) do
    if v == x then
      return k
    end
  end
  return nil
end
