#!/usr/bin/env luvit

JSON = require('json')
p(pcall(JSON.parse, '{"foo":"bar}"}'))
