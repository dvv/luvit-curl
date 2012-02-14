local os = require('os')

-- TODO: replace with real function
local strptime = function(str, format)
  return str:find('2013') and 2000000000 or 0
end

local parse_url = function(str)
  local url = require('url').parse(str)
  --p('URL', str, url)
  return {
    domain = url.hostname,
    port = url.port,
    path = url.pathname
  }
end

-- Cookie archive
local Cookie = require('core').Object:extend()

function Cookie:initialize()
  self.jar = {}
end

function Cookie:get(name)
  return self.jar[name]
end

function Cookie:tostring(domain, path)
  p(self.jar)
end

function Cookie:update(header, url)

  -- update old values
  for k, v in pairs(self.jar) do
    v.old_value = v.value
  end

  -- update values
  if header then

    -- get domain and path
    local uri = parse_url(url)
    if uri.domain:sub(1, 1) ~= '.' then
      uri.domain = '.' .. uri.domain
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
      local cookie = {}

      -- update cookie value
      cookie.value = value

      -- parse key/value attributes
      --p('ATTRS', attrs)
      attrs = attrs:gsub('%s*([%a_][%w_-]*)%s*=%s*(.-)%s*;', function (attr, value)
        --p('ATTR', attr, value)
        attr = attr:lower()
        -- honor only the first occurence of the attribute
        if cookie[attr] then return '' end
        -- silently ignore attributes not listed in RFC
        if attr == 'expires' then
          local expires = strptime(value, '%Y-%m-%d %H:%M:%S %z')
          cookie[attr] = expires
        elseif attr == 'max-age' then
          local delta = tonumber(value)
          if delta and delta >= 0 then
            cookie.expires = os.time() + delta
            cookie[attr] = delta
          end
        elseif attr == 'domain' then
          cookie[attr] = value
        elseif attr == 'path' then
          cookie[attr] = value
        elseif attr == 'port' then
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
        -- silently ignore attributes not listed in RFC
        if attr == 'httponly' or attr == 'secure' then
          cookie[attr] = true
        elseif attr == 'max-age' then
          cookie.expires = os.time()
        end
      end

      --
      -- N.B. we relax requirement for presense of Version= attribute
      -- 

      -- check validity of update
      local valid = true
      -- * The value for the Path attribute is not a prefix of the request-URI
      if cookie.path and uri.path:find(cookie.path, 1, true) ~= 1 then
        valid = false
      end
      -- * The value for the Domain attribute contains no embedded dots,
      --   and the value is not .local
      if cookie.domain and cookie.domain ~= '.local' then
        local dot = cookie.domain:find('.')
        if not dot or dot == 1 or dot == #cookie.domain then
          valid = false
        end
      end
      -- * The effective host name that derives from the request-host does
      --   not domain-match the Domain attribute
      -- TODO: !
      if cookie.domain == false then
        valid = false
      end
      -- * The request-host is a HDN (not IP address) and has the form HD,
      --   where D is the value of the Domain attribute, and H is a string
      --   that contains one or more dots
      -- TODO: !
      if cookie.domain == false then
        valid = false
      end
      -- * The Port attribute has a "port-list", and the request-port was
      --   not in the list
      -- TODO: ???
      if cookie.port == false then
        valid = false
      end

      -- update the cookie
      if not valid then p('INVALID', cookie) end
      if valid then

        -- get existing cookie record or create one
        if not self.jar[name] then
          self.jar[name] = cookie
        else
          for k, v in pairs(self.jar[name]) do if not cookie[k] then cookie[k] = nil end end
          for k, v in pairs(cookie) do self.jar[name][k] = v end
        end

        -- if expires <= now, remove the cookie
        if cookie.expires and cookie.expires <= os.time() then
          -- FIXME: shouldn't be simply cookie.value = nil?
          --cookie = nil
          --self.jar[name] = nil
          cookie.value = nil
          cookie.expires = nil
        end

      end

    end

  end

end

-- module
return {
  Cookie = Cookie,
}
