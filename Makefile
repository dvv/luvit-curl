all: test

test:
	#checkit tests/*
	checkit tests/get_dist_entry.lua

.PHONY: all test
.SILENT:
