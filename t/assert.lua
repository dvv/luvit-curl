local A = { }

A.assert = assert

A.ok = function(a)
  return not not a
end

local function equal(a, b)
  if type(a) == 'table' and type(b) == 'table' then
    -- compare array part
    for k, v in ipairs(a) do
      if not equal(v, b[k]) then return false end
    end
    for k, v in ipairs(b) do
      if not equal(v, a[k]) then return false end
    end
    -- compare hash part
    for k, v in pairs(a) do
      if not equal(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
      if not equal(v, a[k]) then return false end
    end
  else
    return a == b
  end
end
A.equal = equal

A.is_nil = function(a)
  return equal(a, nil)
end

A.is_number = function(a)
  return equal(type(a), 'number')
end

A.is_boolean = function(a)
  return equal(type(a), 'boolean')
end

A.is_string = function(a)
  return equal(type(a), 'string')
end

A.is_table = function(a)
  return equal(type(a), 'table')
end

A.is_array = function(a)
  if not A.is_table(a) then return false end
  for k, v in pairs(a) do
    return false
  end
  return true
end

A.is_hash = function(a)
  if not A.is_table(a) then return false end
  for k, v in ipairs(a) do
    return false
  end
  return true
end

A.throws = function(...)
  local s, e = pcall(...)
  p('NOT?', s, e)
  return A.equal(s, false) and A.ok(e)
end

--
-- self tests
--

assert(A.ok(1))
assert(A.is_nil(nil))
assert(A.throws(A.is_nil, 1))

return A
