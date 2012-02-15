local Table = require('table')
local os = require('os')

-- TODO: implement http://tools.ietf.org/html/rfc6265#section-5.1.1
local strptime = function(str, format)
  return str:find('2013') and 2000000000 or 0
end

local parse_url = function(str)
  local url = require('url').parse(str)
  --p('URL', str, url)
  return {
    domain = url.host,
    path = url.pathname
  }
end

-- http://tools.ietf.org/html/rfc6265#section-5.1.3
local function domain_match(a, b)
  a = a:lower()
  b = b:lower()
  -- The domain string and the string are identical.
  if a == b then return true end
  -- The domain string is a suffix of the string.
  -- The last character of the string that is not included in the
  -- domain string is a %x2E (".") character.
  -- TODO: The string is a host name (i.e., not an IP address).
  if a:match('^%w[%w_-]*%.' .. b) then return true end
  return false
end

-- http://tools.ietf.org/html/rfc6265#section-5.1.4
local function path_match(a, b)
  -- The cookie-path and the request-path are identical.
  if a == b then return true end
  -- The cookie-path is a prefix of the request-path, and the last
  -- character of the cookie-path is %x2F ("/").
  local start, finish = a:find(b, 1, true)
  if start == 1 and b:sub(#b) == '/' then return true end
  -- The cookie-path is a prefix of the request-path, and the first
  -- character of the request-path that is not included in the cookie-path
  -- is a %x2F ("/") character.
  if start == 1 and a:sub(finish + 1, finish + 1) == '/' then return true end
  return false
end

--
-- Cookie archive
--
-- refer to http://tools.ietf.org/html/rfc6265
--

local Cookie = require('core').Object:extend()

function Cookie:initialize()
  self.jar = {}
end

function Cookie.meta.__tostring()
  return '<Cookie>'
end

function Cookie:serialize(url)

  -- get request domain and path
  local uri = parse_url(url)

  -- purge expired cookies
  self:flush()

  -- collect relevant cookies
  -- N.B. servers SHOULD NOT rely upon the serialization order:
  -- http://tools.ietf.org/html/rfc6265#section-4.2.2
  local result = {}
  for _, cookie in ipairs(self.jar) do
    if domain_match(uri.domain, cookie.domain)
        and path_match(uri.path, cookie.path)
        -- filter out expired cookies
        and (not cookie.expires or cookie.expires < os.time())
        -- don't send secure cookies via insecure path
        and (uri.protocol ~= 'https' or not cookie.secure) then
      result[#result + 1] = cookie.name .. '=' .. cookie.value
    end
  end

  return Table.concat(result, '; ')

end

function Cookie:set(cookie)

  -- if cookie with same name, domain and path exists,
  -- replace it
  for i, c in ipairs(self.jar) do
    if c.name == cookie.name
        and c.domain == cookie.domain
        and c.path == cookie.path then
      cookie.old_value = self.jar[i].old_value
      self.jar[i] = cookie
      return
    end
  end

  -- insert new cookie
  self.jar[#self.jar + 1] = cookie

end

function Cookie:get(name, domain, path)

  -- find the cookie
  for i, c in ipairs(self.jar) do
    if c.name == name
        and (not domain or c.domain == domain)
        and (not path or c.path == path) then
      return c
    end
  end

end

function Cookie:flush(non_persistent_as_well)

  -- drop expired and non-persistent cookies
  local now = os.time()
  for i, c in ipairs(self.jar) do
    if (not c.expires and non_persistent_as_well) or c.expires <= now then
      -- TODO: what's the Lua splice?
      self.jar[i] = nil
    end
  end

end

function Cookie:update(header, url)

  -- update old values
  for _, c in ipairs(self.jar) do
    c.old_value = c.value
  end

  -- update values
  if header then

    -- get request domain and path
    local uri = url and parse_url(url)
    if uri and uri.path == '' then
      uri.path = '/'
    end

    -- compensate for ambiguous comma in Expires attribute
    -- N.B. without this commas in Expires can clash with
    -- commas delimiting chunks of composite header
    --p('HEAD?', header)
    header = (header..','):gsub('[Ee]xpires%s*=%s*%w-,%s*(.-[;,])', 'expires=%1')
    --p('HEAD!', header)

    -- for each comma separated chunk in header...
    for chunk in header:gmatch('%s*(.-)%s*,') do
      --p('CHUNK', chunk)

      -- extract cookie name, value and optional trailer
      -- containing various attributes
      local name, value, attrs = (chunk..';'):match('%s*(.-)=(.-)%s*;(.*)')
      --p('COOKIE', name, value, attrs)

      -- temporary cookie data
      local cookie = {
        name = name,
        value = value
      }

      -- parse key/value attributes, if any
      --p('ATTRS', attrs)
      if attrs then

        attrs = attrs:gsub('%s*([%a_][%w_-]*)%s*=%s*(.-)%s*;', function (attr, value)
          --p('ATTR', attr, value)
          attr = attr:lower()
          -- http://tools.ietf.org/html/rfc6265#section-5.2.1
          if attr == 'expires' then
            local expires = strptime(value, '%Y-%m-%d %H:%M:%S %z')
            cookie[attr] = expires
          -- http://tools.ietf.org/html/rfc6265#section-5.2.2
          elseif attr == 'max-age' then
            local delta = tonumber(value)
            if delta then
              if delta > 0 then
                cookie.expires = os.time() + delta
              else
                cookie.expires = 0
              end
            end
          -- http://tools.ietf.org/html/rfc6265#section-5.2.3
          elseif attr == 'domain' then
            if value ~= '' then
              -- drop leading dot
              if value:sub(1, 1) == '.' then
                value = value:sub(2)
              end
              cookie[attr] = value:lower()
            end
          -- http://tools.ietf.org/html/rfc6265#section-5.2.4
          elseif attr == 'path' then
            cookie[attr] = value
          end
          -- consume attribute
          return ''
        end)

        -- parse flag attributes
        --p('ATTR1', attrs)
        for attr in attrs:gmatch('%s*([%w_-]-)%s*;') do
          --p('ATTR', attr)
          attr = attr:lower()
          -- http://tools.ietf.org/html/rfc6265#section-5.2.5
          -- http://tools.ietf.org/html/rfc6265#section-5.2.6
          if attr == 'httponly' or attr == 'secure' then
            cookie[attr] = true
          end
        end

      end

      -- set default values for optional attributes
      if not cookie.domain then
        --cookie.host_only = true
        cookie.domain = uri and uri.domain
      end
      -- http://tools.ietf.org/html/rfc6265#section-5.1.4
      if not cookie.path then
        cookie.path = uri and uri.path:match('^(.*)/')
        if cookie.path == '' then
          cookie.path = '/'
        end
      end

      -- check attributes validity
      -- http://tools.ietf.org/html/rfc6265#section-5.3
      local valid = true

      if not cookie.name then
        valid = false
      end

      -- The value for the Domain attribute contains no embedded dots,
      -- and the value is not .local
      if cookie.domain then
        local dot = cookie.domain:find('.', 2, true)
        if not dot or dot == #cookie.domain then
          valid = false
        end
      end

      -- If the canonicalized request-host does not domain-match the
      -- domain-attribute.
      if cookie.domain and uri and not domain_match(uri.domain, cookie.domain) then
        valid = false
      end

      -- update the cookie
      -- http://tools.ietf.org/html/rfc6265#section-5.3
      if valid then

        -- if expires <= now, remove the cookie
        if cookie.expires and cookie.expires <= os.time() then
          cookie.value = nil
          cookie.expires = nil
        end

        -- update existing cookie record or create one
        self:set(cookie)

      end

    end

  end

end

-- helper assertions
function Cookie:is_set(name, domain, path)
  local c = self:get(name, domain, path)
  return c and c.value and not c.old_value
end

function Cookie:is_updated(name, domain, path)
  local c = self:get(name, domain, path)
  return c and c.value and c.old_value and c.value ~= c.old_value
end

function Cookie:is_same(name, domain, path)
  local c = self:get(name, domain, path)
  return c and c.value == c.old_value
end

-- module
return {
  Cookie = Cookie
}
