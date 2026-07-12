.DEFAULT_GOAL := help

STYLUA ?= stylua
LUACHECK ?= luacheck
NVIM ?= nvim
NVIM_VERSION ?=
DEPDIR ?= .test-deps
CURL ?= curl -fL --retry 5 --retry-delay 5 --retry-connrefused --create-dirs
TEST_HOME ?= $(CURDIR)/.test-home
TEST_WORK ?= $(CURDIR)/.test-work
TEST_HELP_DIR := $(TEST_WORK)/help/doc
TEST_ENV := MARKDOWN_TOOLS_TEST_HOME=$(TEST_HOME) MARKDOWN_TOOLS_TEST_WORK=$(TEST_WORK) XDG_CONFIG_HOME=$(TEST_HOME)/config XDG_DATA_HOME=$(TEST_HOME)/data XDG_CACHE_HOME=$(TEST_HOME)/cache XDG_STATE_HOME=$(TEST_HOME)/state NVIM_LOG_FILE=$(TEST_HOME)/nvim.log
LUA_DIRS := lua plugin tests
DOC_FILE := doc/markdown-tools.txt

ifeq ($(shell uname -s),Darwin)
  ifeq ($(shell uname -m),arm64)
    NVIM_ARCH ?= macos-arm64
  else
    NVIM_ARCH ?= macos-x86_64
  endif
else
  NVIM_ARCH ?= linux-x86_64
endif

ifneq ($(NVIM_VERSION),)
  NVIM_DIR := $(DEPDIR)/nvim-$(NVIM_VERSION)-$(NVIM_ARCH)
  NVIM_STAMP := $(NVIM_DIR)/.installed
  NVIM_TARBALL := $(NVIM_DIR).tar.gz
  NVIM_URL := https://github.com/neovim/neovim/releases/download/$(NVIM_VERSION)/nvim-$(NVIM_ARCH).tar.gz
  TEST_NVIM := $(NVIM_DIR)/nvim-$(NVIM_ARCH)/bin/nvim
  TEST_NVIM_DEPS := $(NVIM_STAMP)
else
  TEST_NVIM := $(NVIM)
  TEST_NVIM_DEPS :=
endif

.PHONY: all help nvim test test-verbose test-pdf-e2e format format-check lint_luacheck lint_stylua lint help-tags help-check check clean

all: help

help:
	@printf '%s\n' \
		'Available targets:' \
		'  make              Show this help message (default).' \
		'  make check        Run lint, tests, and Vim-help validation.' \
		'  make test         Run the isolated Neovim test suite.' \
		'  make test-verbose Run tests with verbose output.' \
		'  make test-pdf-e2e Run a real Pandoc + Typst smoke test.' \
		'  make format       Format Lua sources.' \
		'  make format-check Check Lua formatting.' \
		'  make lint         Run Luacheck and StyLua checks.' \
		'  make help-tags    Regenerate tracked Vim help tags.' \
		'  make help-check   Validate the tracked Vim help tags.' \
		'  make clean        Remove downloaded dependencies and test state.' \
		'' \
		'Variables:' \
		'  NVIM_VERSION=v0.11.7  Test with a downloaded Neovim release.'

nvim: $(TEST_NVIM_DEPS)

ifneq ($(NVIM_VERSION),)
$(NVIM_STAMP):
	$(CURL) $(NVIM_URL) -o $(NVIM_TARBALL)
	rm -rf $(NVIM_DIR)
	mkdir -p $(NVIM_DIR)
	tar -xf $(NVIM_TARBALL) -C $(NVIM_DIR)
	rm -f $(NVIM_TARBALL)
	touch $@
endif

test: $(TEST_NVIM_DEPS)
	@mkdir -p $(TEST_HOME) $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c "lua require('tests.runner').run()" -c qa

test-verbose: $(TEST_NVIM_DEPS)
	@mkdir -p $(TEST_HOME) $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c "lua require('tests.runner').run({ verbose = true })" -c qa

test-pdf-e2e: $(TEST_NVIM_DEPS)
	@command -v pandoc >/dev/null || { echo 'pandoc is required'; exit 1; }
	@command -v typst >/dev/null || { echo 'typst is required'; exit 1; }
	@mkdir -p $(TEST_HOME) $(TEST_WORK)/pdf
	@cp tests/fixtures/pdf.md $(TEST_WORK)/pdf/sample.md
	@$(TEST_ENV) $(TEST_NVIM) --headless --noplugin -i NONE -n -u tests/minimal_init.lua -c "lua require('tests.pdf_e2e').run()" -c qa

format:
	$(STYLUA) $(LUA_DIRS)

format-check:
	$(STYLUA) --color always --check $(LUA_DIRS)

lint_luacheck:
	$(LUACHECK) $(LUA_DIRS)

lint_stylua: format-check

lint: lint_luacheck lint_stylua

help-tags: $(TEST_NVIM_DEPS)
	@mkdir -p $(TEST_HOME) $(TEST_WORK)
	@$(TEST_ENV) $(TEST_NVIM) --headless --clean -u NONE -i NONE -n -c "helptags doc" -c qa

help-check: $(TEST_NVIM_DEPS)
	@rm -rf $(TEST_HELP_DIR)
	@mkdir -p $(TEST_HOME) $(TEST_HELP_DIR)
	@cp $(DOC_FILE) $(TEST_HELP_DIR)/
	@$(TEST_ENV) $(TEST_NVIM) --headless --clean -u NONE -i NONE -n -c "helptags $(TEST_HELP_DIR)" -c qa
	@cmp -s doc/tags $(TEST_HELP_DIR)/tags || { echo 'doc/tags is stale; run make help-tags'; exit 1; }

check: lint test help-check

clean:
	rm -rf $(DEPDIR) $(TEST_HOME) $(TEST_WORK)
