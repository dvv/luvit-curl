local get = require('../request').get

--[[
-- connect should fail gracefully
get('http://1.2.3.4', function (err, data)
  --p(err, data)
  assert(process.env.http_proxy == nil or data == nil)
  --assert(err == "tcp_connect: invalid argument")
end)]]--

--[[
-- JSON should parse ok
get({url='http://loginza.ru:80/api/authinfo?token=a88e7cec94343bae63624b569ab09da5'}, function (err, data)
  --p('LOGINZA', err, data)
  assert(err == nil)
  assert(data.error_message == "Token value value was used previously.")
  assert(data.error_type == "token_validation")
end)]]--

-- redirects are ok, text/html goes verbatim
get({
  url = 'http://google.com',
  headers = {
    ['User-Agent'] = 'Mozilla/5.0 (X11; Linux i686) AppleWebKit/535.7 (KHTML, like Gecko) Chrome/16.0.912.63 Safari/535.7',
    ['Accept'] = 'text/html; charset=UTF-8'
  },
  redirects = 3,
}, function (err, data)
  p('GOOGLE', err, data)
  --assert(err == nil)
  --assert(data:sub(1, 1) == '<')
end)

-- redirects are ok, text/html goes verbatim
--[[
get({
  url = 'http://git.io/4X-LBA',
  headers = {['User-Agent'] = 'Wget 1.14'},
  redirects = 3,
}, function (err, data)
  p('GITIO', err, data)
  --assert(err == nil)
  --assert(data:sub(1, 1) == '<')
end)]]--


-- TODO: https://

-- TODO: proxy
