DEPS_DIR := .deps
PLENARY := $(DEPS_DIR)/plenary.nvim

.PHONY: deps test lint

deps:
	@mkdir -p $(DEPS_DIR)
	@test -d $(PLENARY) || git clone --depth 1 https://github.com/nvim-lua/plenary.nvim $(PLENARY)

test: deps
	nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua' }"

lint:
	stylua --check lua/ tests/ plugin/
	luacheck lua/ tests/ plugin/
