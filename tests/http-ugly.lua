--[[

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

require("helper")

local http = require('http')
local delay = require('timer').setTimeout

local HOST = "127.0.0.1"
local PORT = process.env.PORT or 10080
local server = nil
local client = nil

server = http.createServer(HOST, PORT, function(request, response)
  p('server connection')
  assert(request.method == "GET")
  assert(request.url == "/foo")
  assert(request.headers.bar == "cats")
  request:on('data', function (data)
    p('server request data', data)
  end)
  request:on('end', function ()
    p('server request end')
  end)
  request:on('error', function (err)
    p('server request error', err)
  end)
  response:on('data', function (data)
    p('server response data', data)
  end)
  response:on('end', function ()
    p('server response end')
    delay(500, function ()
      process.exit()
    end)
  end)
  response:on('error', function (err)
    p('server response error', err)
  end)
  -- long polling
  response:write("Hello")
  response:finish()
  --response.socket:close()
end)

local request
request = http.request(
  {
    host = HOST,
    port = PORT,
    path = "/foo",
    headers = {bar = "cats"}
  },
  function (response)
    p('client got response')
    assert(response.status_code == 200)
    assert(response.version_major == 1)
    assert(response.version_minor == 1)
    -- TODO: fix refcount so this isn't needed.
    --process.exit()
    response:write('foo')
    delay(500, function ()
      --request:close()
      --p('client closed socket')
      --response.socket:close()
      --response:finish()
      --request:close()
    end)
end)

request:on('end', function ()
  p('client request end')
end)
request:on('error', function (err)
  p('client request error', err)
end)
