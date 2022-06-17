#include <sys/types.h>
#include <sys/random.h>
#include <sys/utsname.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <time.h>
#include <dirent.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

static int lua_uname(lua_State* ls)
{
	struct utsname buf;
	if (0 != uname(&buf))
		luaL_error(ls, strerror(errno));

	lua_pushstring(ls, buf.sysname);
	return 1;
}

static int lua_cwd(lua_State* ls)
{
	char path[0x100];
	if (NULL == getcwd(path, sizeof(path)))
		luaL_error(ls, strerror(errno));

	lua_pushstring(ls, path);
	return 1;
}

static int lua_ls(lua_State* ls)
{
	const char* path = luaL_checkstring(ls, 1);
	DIR* dir = opendir(path);
	if (NULL == dir) {
		const char* err = strerror(errno);
		luaL_error(ls, "%s: \'%s\'", err, path);
	}
	lua_newtable(ls);
	do {
		struct dirent* ent = readdir(dir);
		if (NULL == ent)
			break;
		switch (ent->d_type) {
		case DT_DIR:
			lua_pushliteral(ls, "DIR");
			break;
		case DT_REG:
			lua_pushliteral(ls, "FILE");
			break;
		case DT_LNK:
			lua_pushliteral(ls, "LINK");
			break;
		default:
			lua_pushliteral(ls, "UNKNOWN");
		}
		lua_setfield(ls, -2, ent->d_name);

	} while(1);
	closedir(dir);
	return 1;
}

static int lua_sleep(lua_State* ls)
{
	int ms = luaL_checkinteger(ls, 1);
	struct timespec ts = {
		ms / 1000,
		(ms % 1000) * 1000 * 1000,
	};
	if (0 != nanosleep(&ts, NULL)) {
		luaL_error(ls, strerror(errno));
	}
	return 0;
}

static int lua_random(lua_State* ls)
{
	int length = luaL_optinteger(ls, 1, 0);
	char buffer[0x100];
	if (length < 0 || length > 0x100)
		luaL_error(ls, "random: invalid size %d", length);
	if (length) {
		length = getrandom(buffer, length, 0);
		if (length < 0)
			luaL_error(ls, "random: failed %d", errno);
		lua_pushlstring(ls, buffer, length);
	} else {
		length = getrandom(buffer, sizeof(lua_Integer), 0);
		if (length != sizeof(lua_Integer))
			luaL_error(ls, "random: failed %d", errno);
		lua_pushinteger(ls, *(lua_Integer*)buffer);
	}
	return 1;
}


static const struct luaL_Reg lib[] = {
	{ "uname",	lua_uname },
	{ "cwd",	lua_cwd },
	{ "ls",		lua_ls },
	{ "sleep",	lua_sleep },
	{ "random",	lua_random },
	{ NULL, NULL },
};

int luaopen_lua_platform(lua_State* ls)
{
	luaL_newlib(ls, lib);
	return 1;
}
