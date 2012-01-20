Curl
=====

A library to ease making HTTP requests and parse responses

Usage
-----

```lua
local Curl = require('curl')

-- get twitter timeline
get({
  url = 'http://twitter.com/status/user_timeline/creationix.json?count=2&callback=foo',
}, function (err, data)
  p(err, data)
  -- should see pretty-printed table here
end)
```

License
-------

[MIT](curl/license.txt)
