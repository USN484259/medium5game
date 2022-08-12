local rng_table = {
	lua = function(seed)
		if seed then
			math.randomseed(seed)
		end
		return {
			length = 15,
			raw = function(self)
				return math.random(0, 0x7FFF)
			end,
			uniform = function(self, a, b)
				return math.random(a, b)
			end,
		}
	end,

	lcg = function(seed)
		local function step(seed)
			local res = seed * 0x5DEECE66D + 11
			return res & 0xFFFFFFFFFFFF
		end
		return {
			seed = seed or 1,
			length = 32,
			raw = function(self)
				self.seed = step(self.seed)
				return self.seed >> 16
			end,
			uniform = function(self, a, b)
				self.seed = step(self.seed)
				return a + self.seed % (b - a + 1)
			end,
		}
	end,

	os = function()
		local platform_rng = require("lua_platform").random

		return {
			length = 64,
			raw = function(self)
				return platform_rng()
			end,
			uniform = function(self, a, b)
				local val = platform_rng()
				return a + math.abs(val % (b - a + 1))
			end,
		}
	end
}

local rng = nil

local function random_setup(source, ...)
	local func = rng_table[source]
	if func then
		rng = func(...)
	else
		error("invalid rng source " .. source)
	end

	return rng.length
end

local function random(mode, ...)
	if not rng then
		error("rng not setup")
	end
	local func = rng[mode]
	if func then
		return func(rng, ...)
	else
		error("rng doesn't support mode " .. mode)
	end
end

local locale_table = nil

local function locale_setup(locale, folder)
	local path = folder or "."
	if string.sub(path, -1) ~= '/' then
		path = path .. '/'
	end
	path = path .. locale .. ".lua"

	local chunk, err = loadfile(path)
	if not chunk then
		error("failed to load locale " .. path)
	end

	locale_table = chunk()
end

local function translate(name, ...)
	local cnt = select("#", ...)
	if cnt > 0 then
		local prefix = ""
		for i = cnt, 1, -1 do
			prefix = prefix .. (select(i, ...)) .. '.'
		end
		name = prefix .. name
	end

	-- print("translating key: " .. name)

	local l = locale_table
	for k in string.gmatch(name, "([^%.]+)") do
		if type(l) ~= "table" then
			return name
		end
		l = l[k]
	end

	if type(l) == "string" then
		return l
	else
		return name
	end
end

local function find(table, val, cmp)
	for k, v in pairs(table) do
		if (cmp and cmp(v, val)) or (v == val) then
			return k, v
		end
	end

	return nil
end

local function stable_sort(table, cmp)
	cmp = cmp or function(a, b)
		return a < b
	end
	for i = 1, #table - 1, 1 do
		local p = i
		for j = i + 1, #table, 1 do
			if cmp(table[j], table[p]) then
				p = j
			end
		end
		if p ~= i then
			table[i], table[p] = table[p], table[i]
		end
	end
end

local function dump_table(table, prefix)
	for k,v in pairs(table) do
		print((prefix or "") .. k,v)
		if type(v) == "table" then
			dump_table(v, (prefix or "") .. k .. ".")
		end
	end
end

local function copy_table(src, recursive)
	local res = {}
	for k, v in pairs(src) do
		if recursive and type(v) == "table" then
			res[k] = copy_table(v, recursive)
		else
			res[k] = v
		end
	end

	return res
end

local function append_table(tar, src)
	for i = 1, #src, 1 do
		table.insert(tar, src[i])
	end
	return tar
end

local function unique_insert(tab, val, cmp)
	cmp = cmp or function(a, b)
		return a == b
	end
	for k, v in pairs(tab) do
		if cmp(v, val) then
			return
		end
	end

	return table.insert(tab, val)
end

local function merge_table(tar, src, weak)
	for k, v in pairs(src) do
		if type(v) == "table" and type(tar[k]) == "table" then
			tar[k] = merge_table(tar[k], v)
		else
			tar[k] = v
		end
	end

	for k, v in pairs(weak or {}) do
		if type(tar[k]) == "nil" then
			tar[k] = v
		end
	end

	return tar
end

return {
	random_setup = random_setup,
	random = random,
	locale_setup = locale_setup,
	translate = translate,
	find = find,
	stable_sort = stable_sort,
	dump_table = dump_table,
	copy_table = copy_table,
	append_table = append_table,
	unique_insert = unique_insert,
	merge_table = merge_table,
}
