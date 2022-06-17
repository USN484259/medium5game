#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <windows.h>


typedef BOOLEAN (*rng_func)(PVOID, ULONG);

// https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-rtlgenrandom
static rng_func random_func(void)
{
	static rng_func RtlGenRandom = NULL;

	if (NULL == RtlGenRandom) {
		HMODULE mod = LoadLibrary("Advapi32.dll");
		if (NULL == mod)
			return NULL;

		RtlGenRandom = GetProcAddress(mod, "SystemFunction036");
	}

	return RtlGenRandom;
}

static int lua_uname(lua_State* ls)
{
	lua_pushliteral(ls, "Windows");
	return 1;
}

static int lua_cwd(lua_State* ls)
{
	char path[0x100];
	if (0 == GetCurrentDirectory(sizeof(path), path)) {
		lua_pushinteger(ls, GetLastError());
		lua_error(ls);
	}

	lua_pushstring(ls, path);
	return 1;
}

static int lua_ls(lua_State* ls)
{
	WIN32_FIND_DATA data;
	HANDLE h;
	const char* path = luaL_checkstring(ls, 1);
	lua_pushliteral(ls, "\\*");
	lua_concat(ls, 2);

	path = luaL_checkstring(ls, 1);
	lua_newtable(ls);

	h = FindFirstFile(path, &data);
	if (INVALID_HANDLE_VALUE == h) {
		DWORD err = GetLastError();
		if (ERROR_FILE_NOT_FOUND == err)
			return 1;

		lua_pushinteger(ls, err);
		lua_error(ls);
	}

	do {
		if (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)
			lua_pushliteral(ls, "DIR");
		else
			lua_pushliteral(ls, "FILE");

		lua_setfield(ls, -2, data.cFileName);

		if (!FindNextFile(h, &data)) {
			DWORD err = GetLastError();
			if (ERROR_NO_MORE_FILES == err)
				break;

			FindClose(h);
			lua_pushinteger(ls, err);
			lua_error(ls);
		}
	} while(1);

	FindClose(h);

	return 1;
}

static int lua_sleep(lua_State* ls)
{
	int ms = luaL_checkinteger(ls, 1);
	Sleep(ms);
	return 0;
}

static int lua_random(lua_State* ls)
{
	int length;
	char buffer[0x100];
	rng_func rng = random_func();

	if (NULL == rng)
		luaL_error(ls, "rng function failed to load");

	length = luaL_optinteger(ls, 1, 0);
	if (length < 0 || length > 0x100)
		luaL_error(ls, "random: invalid size %d", length);
	if (length) {
		if (!rng(buffer, length))
			luaL_error(ls, "random: failed");

		lua_pushlstring(ls, buffer, length);
	} else {
		if (!rng(buffer, sizeof(lua_Integer)))
			luaL_error(ls, "random: failed");

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
