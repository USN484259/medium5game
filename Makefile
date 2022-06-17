
ifeq ($(PLAT), mingw)
	SRC=lib/lua_platform_win32.c
	DST=lua_platform.dll
	LDFLAGS= -I $(LUALIB_PATH) liblua.dll
else
	SRC=lib/lua_platform_posix.c
	DST=lua_platform.so
	LDFLAGS=$(shell pkg-config --cflags --libs lua-5.3)
endif


$(DST):	$(SRC)
	$(CC) -g -fPIC -shared -o $@ $< $(LDFLAGS)

