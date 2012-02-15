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

  -- collect relevant cookies
  -- N.B. servers SHOULD NOT rely upon the serialization order:
  -- http://tools.ietf.org/html/rfc6265#section-4.2.2
  local result = {}
  for name, cookie in pairs(self.jar) do
    if domain_match(uri.domain, cookie.domain)
        and path_match(uri.path, cookie.path)
        -- filter out expired cookies
        and (not cookie.expires or cookie.expires < os.time())
        -- don't send secure cookies via insecure path
        and (uri.protocol ~= 'https' or not cookie.secure) then
      result[#result + 1] = name .. '=' .. cookie.value
    end
  end

  return Table.concat(result, '; ')

end

function Cookie:update(header, url)

  -- update old values
  for k, v in pairs(self.jar) do
    v.old_value = v.value
  end

  -- update values
  if header then

    -- get request domain and path
    local uri = url and parse_url(url)
    -- effective host name
    if uri and not uri.domain:find('.', 1, true) then
      uri.domain = uri.domain .. '.local'
    end
    if uri and uri.path == '' then
      uri.path = '/'
    end

    -- compensate for ambiguous comma in Expires attribute
    -- N.B. without this commas in Expires can clash with
    -- commas delimiting chunks of composite header
    header = (header..','):gsub('[Ee]xpires=.-, (.-[;,])', 'expires=%1')
    --p('HEAD', header)

    -- for each comma separated chunk in header...
    for chunk in header:gmatch('%s*(.-)%s*,') do
      --p('CHUNK', chunk)

      -- extract cookie name, value and optional trailer
      -- containing various attributes
      local name, value, attrs = (chunk..';'):match('%s*(.-)=(.-)%s*;(.*)')
      --p('COOKIE', name, value, attrs)

      -- couldn't extract cookie name?
      if not name then
        -- header chunk has bad format -- ignore it
        -- FIXME: error()?
        break
      end

      -- cookie name starting with $ are reserved
      if name:sub(1, 1) == '$' then
        break
      end

      -- temporary cookie data
      local cookie = {
        value = value
      }

      -- parse key/value attributes
      --p('ATTRS', attrs)
      attrs = attrs:gsub('%s*([%a_][%w_-]*)%s*=%s*(.-)%s*;', function (attr, value)
        --p('ATTR', attr, value)
        attr = attr:lower()
        -- honor only the first occurence of the attribute
        if cookie[attr] then return '' end
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
            cookie[attr] = cookie.expires
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

      -- set default values for optional attributes
      if not cookie.domain then
        cookie.domain = uri and uri.domain
      end
      -- http://tools.ietf.org/html/rfc6265#section-5.1.4
      if not cookie.path then
        cookie.path = uri and uri.path:match('^(.*)/')
        if cookie.path == '' then
          cookie.path = '/'
        end
      end

      --
      -- N.B. we relax requirement for presense of Version= attribute
      --

      -- check validity of update
      local valid = true
      -- * The value for the Path attribute is not a prefix of the request-URI
      if cookie.path and uri and not path_match(uri.path, cookie.path) then
        valid = false
      end
      -- * The value for the Domain attribute contains no embedded dots,
      --   and the value is not .local
      if cookie.domain and cookie.domain ~= '.local' then
        local dot = cookie.domain:find('.', 2, true)
        if not dot or dot == #cookie.domain then
          valid = false
        end
      end
      -- * The effective host name that derives from the request-host does
      --   not domain-match the Domain attribute
      -- * The request-host is a HDN (not IP address) and has the form HD,
      --   where D is the value of the Domain attribute, and H is a string
      --   that contains one or more dots
      -- N.B. we handle the latter case in domain_match()
      if cookie.domain and uri and not domain_match(uri.domain, cookie.domain) then
        valid = false
      end

      -- update the cookie
      if valid then

        -- if expires <= now, remove the cookie
        if cookie.expires and cookie.expires <= os.time() then
          cookie.value = nil
          cookie.expires = nil
        end

        -- update existing cookie record or create one
        -- TODO: rework
        if not self.jar[name] then
          self.jar[name] = cookie
        else
          for k, v in pairs(self.jar[name]) do
            if not cookie[k] and k ~= 'old_value' then
              self.jar[name][k] = nil
            end
          end
          for k, v in pairs(cookie) do
            self.jar[name][k] = v
          end
        end

      end

    end

  end

end

-- helper assertions
function Cookie:is_set(name)
  local c = self.jar[name]
  return c and c.value and not c.old_value
end

function Cookie:is_updated(name)
  local c = self.jar[name]
  return c and c.value and c.old_value and c.value ~= c.old_value
end

function Cookie:is_same(name)
  local c = self.jar[name]
  return c and c.value == c.old_value
end

-- module
return {
  Cookie = Cookie
}
