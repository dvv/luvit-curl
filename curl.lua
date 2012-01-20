--
-- HTTP request helpers
--

local Error = require('error')
local DNS = require('dns')
local resolve = DNS.resolve4
local isIP = DNS.isIP
local http_request = require('http').request
local parse_url = require('url').parse
local parse_json = require('json').parse
local join = require('table').concat
local parse_query = require('querystring').parse
local String = require('string')
local sub = String.sub
local match = String.match

--
-- given string `body` and optional `content_type`,
-- try to compose table representing th body.
-- JSON should be decoded, urlencoded data should be parsed
--
local function parse_body(body, content_type, callback)

  -- allow optional content-type
  if type(content_type) == 'function' then
    callback = content_type
    content_type = nil
  end

  -- first char allows to distinguish JSON
  local char = sub(body, 1, 1)
  -- JSON?
  if char == '[' or char == '{' then
    -- try to decode JSON
    local status, result = pcall(parse_json, body, {
      use_null = true,
      --allow_comments = true,
      --dont_validate_strings = true,
      --allow_trailing_garbage = true,
      --allow_multiple_values = true,
      --allow_partial_values = true,
    })
    if status then
      body = result
    end
  -- html?
  elseif char == '<' then
    -- nothing needed
  -- analyze content-type
  else
    if content_type then
      content_type = match(content_type, '([^;]+)')
    end
    if     content_type == 'application/www-urlencoded'
        or content_type == 'application/x-www-form-urlencoded'
    then
      -- try to parse urlencoded
      body = parse_query(body)
    end
  end

  --
  if callback then
    callback(nil, body)
  else
    return body
  end

end

--
-- given a stream `req`, try to drain pending data and parse it.
-- useful for both outgoing and incoming requests
--
local function parse_request(req, callback)

  -- collect data
  local body = { }
  local length = 0
  req:on('data', function (chunk, len)
    length = length + 1
    body[length] = chunk
  end)

  -- parse data, try to honor Content-Type:
  req:on('end', function ()
    parse_body(join(body), req.headers['content-type'], callback)
  end)

end

--
-- issue an HTTP request and report parsed response
--
defaults = {
  proxy = true,
  redirects = 10,
  parse = true, -- whether to parse the response
}

local function request(options, callback)

  setmetatable(options, { __index = defaults })

  -- parse URL
  local parsed = options
  if options.url then
    parsed = parse_url(options.url)
    setmetatable(parsed, { __index = options })
  end

  -- collect HTTP request options
  local params = {
    host = parsed.hostname or parsed.host,
    port = parsed.port,
    path = parsed.pathname .. parsed.search,
    method = options.method,
    headers = options.headers,
  }

  -- honor proxy, if any
  local proxy = options.proxy
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
    params.path = options.url
  end

  --p('PARAMS', params)
  -- resolve target host name
  -- FIXME: the whole resolve thingy should go deeper to TCP layer
  local status, err = pcall(resolve, params.host, function (err, ips)

    -- DNS errors are ignored if host name looks like a valid IP
    if err and not isIP(params.host) then
      callback(err)
      return
    end
    --p('IP', err, ips)
    -- FIXME: should try every IP, in case of error
    if ips then params.host = ips[1] end

    --p('PARAMS', params)
    --TODO: set Content-Length: if options.data
    -- issue the request
    local client = http_request(params, function (req)

      -- request is done ok. send data, if any valid provided
      if options.data and type(options.data) == 'string' then
        req:write(options.data)
      end

      local st = req.status_code
      -- handle redirect
      if st > 300 and st < 400 and req.headers.location then
        -- can follow new location?
        if options.redirects and options.redirects > 0 then
          -- FIXME: spoils original options. make it feature? ;)
          options.redirects = options.redirects - 1
          options.url = req.headers.location
          -- for short redirects (RFC2616 compliant?) prepend current host name
          if not parse_url(options.url).host then
            options.url = parsed.protocol .. '://' .. parsed.host .. options.url
          end
          -- request redirected location
--p('ST', options)
          request(options, callback)
        -- can't follow
        else
          -- FIXME: what to do? so far let's think it's ok, but no data
          callback(nil)
        end
        return
      -- report HTTP errors
      elseif st >= 400 then
        err = Error.new(data)
        -- FIXME: should reuse status_code_message from Response?
        err.code = st
        callback(err)
        return
      end

      -- request was ok

      -- to parse or not to parse the response
      if options.parse then
        -- parse the response
        parse_request(req, callback)
      else
        -- just return the connected request
        callback(nil, req)
      end

    end)

    -- purge issued request
    client:on('end', function ()
      client:close()
    end)
    -- pipe errors to callback
    client:on('error', callback)

  end)

  if not status then
    callback(err)
  end

end

local function get(options, callback)
  options.method = 'GET'
  request(options, callback)
end

local function post(options, data, callback)
  options.method = 'POST'
  options.data = data
  request(options, callback)
end

-- module
return {
  request = request,
  get = get,
  post = post,
  parse = parse_body,
  parse_request = parse_request,
}
