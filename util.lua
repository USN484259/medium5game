local function find(table, val, cmp)
	for k, v in pairs(table) do
		if (cmp and cmp(v, val)) or (v == val) then
			return k
		end
	end

	return nil
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

local function merge_table(tar, src)
	for k,v in pairs(src) do
		if type(v) == "table" and type(tar[k]) == "table" then
			tar[k] = merge_table(tar[k], v)
		else
			tar[k] = v
		end
	end

	return tar
end

return {
	find = find,
	dump_table = dump_table,
	copy_table = copy_table,
	append_table = append_table,
	merge_table = merge_table,
}
