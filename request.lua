--
-- HTTP request helpers
--

local resolve = require('dns').resolve4
local http_request = require('http').request
local parse_url = require('url').parse
local json_decode = require('json').decode
local join = require('table').concat
local parse_query = require('querystring').parse
local String = require('string')
local sub = String.sub
local match = String.match

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
    local status, result = pcall(json_decode, body)
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
    if content_type == 'application/www-urlencoded' or content_type == 'application/x-www-form-urlencoded' then
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

local function request(url, method, data, callback)
  local parsed = parse_url(url)
  --p('INIT', parsed)
  local params = {
    host = parsed.hostname or parsed.host,
    port = parsed.port,
    path = parsed.pathname .. parsed.search,
    method = method,
  }
  -- honor proxy, if any
  local proxy = process.env[parsed.protocol .. '_proxy']
  if proxy then
    parsed = parse_url(proxy)
    params.host = parsed.hostname or parsed.host
    params.port = parsed.port
    params.path = url
    --p('PROXIED', params, parsed)
  end
  -- FIXME: the whole resolve thingy should go deeper to TCP layer
  resolve(params.host, function (err, ip)
    if err then
      -- FIXME: employ is_IP
      if not match(params.host, '%d+%.%d+.%d+.%d+') then
        return callback(err)
      end
    end
    --p('IP', err, ip)
    if ip then params.host = ip[1] end
    --p('PARAMS', params)
    http_request(params, function (err, req)
      if err then return callback(err) end
      --p('REQ', req)
      if data then
        req:write(data)
      end
      parse_request(req, callback)
      req:on('end', function ()
        req:close()
      end)
    end)
  end)
end

local function get(url, callback)
  request(url, 'GET', nil, callback)
end

local function post(url, data, callback)
  request(url, 'POST', data, callback)
end

-- module
return {
  request = request,
  get = get,
  post = post,
  parse = parse_body,
  parse_request = parse_request,
}
