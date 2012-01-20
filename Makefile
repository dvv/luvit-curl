all: test

test:
	luvit -e 'require("lua-bourbon").run()'

.PHONY: all test
