all: test

test:
	#checkit tests/*
	checkit tests/curl.lua

.PHONY: all test
.SILENT:
