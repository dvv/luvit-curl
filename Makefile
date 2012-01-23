all: test

test:
	checkit tests/*

.PHONY: all test
.SILENT:
