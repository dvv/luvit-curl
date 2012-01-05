--
-- HTTP request helpers
--

local resolve = require('dns').resolve4
local http_request = require('http').request
local parse_url = require('url').parse
local json_decode = require('json').decode
local join = require('table').concat
local parse_query = require('./qs').parse
local String = require('string')
local sub = String.sub
local match = String.match

local function parse_body(body, callback)

  -- first char allows to distinguish JSON
  local char = sub(body, 1, 1)
  -- JSON?
  if char == '[' or char == '{' then
    -- try to decode JSON
    local status, result = pcall(json_decode, body)
    if status then
      body = result
    end
  -- urlencoded or plain text?
  else
    -- try to parse urlencoded
    local vars = parse_query(body)
    -- if resulting table is not empty
    for _, _ in pairs(vars) do
      -- use it
      body = vars
      break
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
  req:on('data', function(chunk, len)
    length = length + 1
    body[length] = chunk
  end)

  -- parse data
  req:on('end', function()
    -- merge data chunks
    parse_body(join(body), callback)
  end)

end

local function request(url, method, data, callback)
  local parsed = parse_url(url)
  --p(parsed)
  local params = {
    host = parsed.host,
    port = parsed.port,
    path = parsed.pathname .. parsed.search,
    method = method,
  }
  local proxy = process.env[parsed.protocol .. '_proxy']
  if proxy then
    parsed = parse_url(proxy)
    params.host = parsed.host
    params.path = url
  end
  resolve(params.host, function(err, ip)
    if err then
      if not match(params.host, '%d+%.%d+.%d+.%d+') then
        return callback(err)
      end
    end
    --p('IP', err, ip)
    params.host = ip
    p(params)
    http_request(params, function(err, req)
      if err then return callback(err) end
      if data then
        req:write(data)
      end
      parse_request(req, callback)
      req:on('end', function()
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
