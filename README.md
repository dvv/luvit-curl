Curl
=====

A library to ease making HTTP requests and parse responses

Usage
-----

```lua
local get = require('curl').get

-- get twitter timeline
get({
  url = 'http://twitter.com/status/user_timeline/creationix.json?count=2&callback=foo',
}, function (err, data)
  p(err, data)
  -- should see pretty-printed table of one or two records here
end)
```

License
-----

[MIT](luvit-curl/license.txt)
