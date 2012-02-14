--
-- HTTP request helpers
--

local Object = require('core').Object
local Error = require('core').Error
local HTTP = require('http')
local parse_url = require('url').parse
local parse_request = require('./body').parse_request

--
-- HTTP request
--
local Curl = Object:extend()

-- default options
Curl.defaults = {
  proxy = true,
  redirects = 10,
  parse = true, -- whether to parse the response body
}

function Curl:initialize(options)
  self.options = setmetatable(options or {}, { __index = Curl.defaults })
end

function Curl:request(callback)

  -- parse URL
  local parsed = self.options
  if self.options.url then
    parsed = parse_url(self.options.url)
    setmetatable(parsed, { __index = self.options })
  end

  -- collect HTTP request options
  local params = {
    host = parsed.hostname or parsed.host,
    port = parsed.port,
    path = parsed.pathname .. parsed.search,
    method = self.options.method,
    headers = self.options.headers,
  }

  -- honor proxy, if any
  local proxy = self.options.proxy
  -- proxy can be string which is used verbatim,
  -- or boolean true to use system proxy
  if proxy == true then
    proxy = process.env[parsed.protocol .. '_proxy']
  end
  -- proxying means...
  if proxy then
    -- ...request the proxy host
    parsed = parse_url(proxy)
    params.host = parsed.hostname or parsed.host
    params.port = parsed.port
    -- ...with path equal to original URL
    params.path = self.options.url
  end

  --p('PARAMS', params)
  --TODO: set Content-Length: if options.data

  -- issue the request
  local req
  req = HTTP.request(params, function (res)

    local st = res.status_code
    -- handle redirect
    if st > 300 and st < 400 and res.headers.location then
      -- can follow new location?
      if self.options.redirects and self.options.redirects > 0 then
        -- FIXME: spoils original options. make it feature? ;)
        self.options.redirects = self.options.redirects - 1
        self.options.url = res.headers.location
        -- for short redirects (RFC2616 compliant?) prepend current host name
        if not parse_url(self.options.url).host then
          self.options.url = parsed.protocol .. '://' .. parsed.host .. self.options.url
        end
        -- request redirected location
--p('ST', options)
        self:request(callback)
        return
      -- can't follow
      else
        -- FIXME: what to do? so far let's think it's ok, proceed to data parsing
        --callback(nil)
      end
    -- report HTTP errors
    elseif st >= 400 then
      err = Error:new(data)
      -- FIXME: should reuse status_code_message from Response?
      err.code = st
      callback(err)
      return
    end

    -- request was ok

    -- to parse or not to parse the response
    if self.options.parse then
      -- parse the response
      parse_request(res, callback)
    else
      -- just return the connected request
      callback(nil, res)
    end

  end)

  -- purge issued request
  req:once('end', function ()
    req:close()
  end)

  -- pipe errors to callback
  req:once('error', function (err)
    req:close()
    callback(err)
    callback = function () end
  end)

  return req

end

function Curl:finish(data)
end

local function get(options, callback)
  local curl = Curl:new(options)
  curl.options.method = 'GET'
  local req = curl:request(callback)
  --req:close()
  --??req._handle:shutdown()
end

local function post(options, data, callback)
  local curl = Curl:new(options)
  curl.options.method = 'POST'
  local req = curl:request(callback)
  if type(data) == 'string' then
    req:write(data)
  end
  --req:close()
end

-- module
return {
  Curl = Curl,
  get = get,
  post = post,
}
