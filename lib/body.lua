--
-- HTTP request helpers
--

local Table = require('table')
local parse_url = require('url').parse
local parse_json = require('json').parse
local parse_query = require('querystring').parse

--
-- given string `body` and optional `content_type`,
-- try to compose table representing th body.
-- JSON/JSONP should be decoded, urlencoded data should be parsed
--
local function parse_body(body, content_type, callback)

  local err

  --p('CTYPE', content_type)
  -- allow optional content-type
  if type(content_type) == 'function' then
    callback = content_type
    content_type = nil
  end
  if content_type then
    content_type = content_type:match('([^;]+)')
  end

  -- first char allows to distinguish JSON
  local char = body:sub(1, 1)
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
    else
      err = result
    end
  -- JSONP?
  elseif content_type == 'application/javascript' then
    -- extract JSON payload
    local func, json = body:match('^([%w_][%a_]*)%((.+)%);?$')
    -- try to decode JSON
    if func and json then
      local status, result = pcall(parse_json, json, {
        use_null = true,
      })
      if status then
        body = result
        -- TODO: how to report `func`?
      else
        err = result
      end
    end
  -- html?
  elseif char == '<' then
    -- nothing needed
  -- analyze content-type
  else
    if     content_type == 'application/www-urlencoded'
        or content_type == 'application/x-www-form-urlencoded'
    then
      -- try to parse urlencoded
      body = parse_query(body)
    end
  end

  --
  if callback then
    callback(err, body)
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
--p('PARSE', req)
    parse_body(Table.concat(body), req.headers['content-type'], callback)
  end)

end

-- module
return {
  parse_body = parse_body,
  parse_request = parse_request,
}
