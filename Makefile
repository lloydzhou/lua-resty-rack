OPENRESTY_PREFIX=/usr/local/openresty

PREFIX ?=          /usr/local/openresty
LUA_INCLUDE_DIR ?= $(PREFIX)/include
LUA_LIB_DIR ?=     $(PREFIX)/lualib/$(LUA_VERSION)
INSTALL ?= install

.PHONY: all test install

all: ;

install: all
		$(INSTALL) -d $(DESTDIR)/$(LUA_LIB_DIR)/resty/rack
		$(INSTALL) lib/resty/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty
		$(INSTALL) lib/resty/rack/*.lua $(DESTDIR)/$(LUA_LIB_DIR)/resty/rack

test: all
		PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I../test-nginx/lib -r t

