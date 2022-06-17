local util = require("core/util")
local core = require("core/core")

local list

local function buff_get(entity, name)
	if string.sub(name, 1, 5) ~= "buff." then
		name = "buff." .. name
	end
	for k, b in pairs(entity.buff) do
		if b.name == name then
			return b
		end
	end
end

local function buff_remove(entity, tar)
	if type(tar) == "string" and string.sub(tar, 1, 5) ~= "buff." then
		tar = "buff." .. tar
	end
	for i = 1, #entity.buff, 1 do
		local b = entity.buff[i]
		if (type(tar) == "string" and b.name == tar) or (tar == b) then
			if b.remove then
				b:remove()
			end
			b.removed = true
			table.remove(entity.buff, k)
			return b
		end
	end
end

local function buff_insert(initial_tick, entity, name, ...)
	local b
	if type(name) == "string" then
		if not list then
			list = require("base/buff")
		end
		b = list[name](...)
	elseif type(name) == "table" then
		b = util.copy_table(name)
	elseif type(name) == "function" then
		b = name(...)
	else
		error(name)
	end

	b.owner = entity

	if b.initial and not b:initial() then
		return
	end

	if initial_tick and b.tick then
		for i = 1, #b.tick, 1 do
			local f = b.tick[i]
			if f[1] < core.priority.damage and not f[2](b) then
				return
			end
		end
	end

	table.insert(entity.buff, b)
	return b
end

local function buff_tick(team)
	local queue = {}
	for k, e in pairs(team) do
		local new_buff = {}
		for i = 1, #e.buff, 1 do
			local b = e.buff[i]
			if core.common_tick(b) then
				table.insert(new_buff, b)
				if b.tick then
					for k, v in pairs(b.tick) do
						table.insert(queue, {
							buff = b,
							priority = v[1],
							func = v[2],
						})
					end
				end
			elseif b.remove then
				b:remove()
			end
		end
		e.buff = new_buff
	end

	util.stable_sort(queue, function(a, b)
		return a.priority < b.priority
	end)

	for i = 1, #queue, 1 do
		local f = queue[i]
		local b = f.buff

		if not b.removed and not f.func(b) then
			buff_remove(b.owner, b)
		end
	end
end

local function buff_defer(team)
	local queue = {}
	for k, e in pairs(team) do
		for k, b in pairs(e.buff) do
			if b.defer then
				table.insert(queue, b)
			end
		end
	end
	table.sort(queue, function(a, b)
		return a.defer[1] < b.defer[1]
	end)
	for i = 1, #queue, 1 do
		local b = queue[i]
		b.defer[2](b)
	end
end

return {
	insert = function(...)
		return buff_insert(true, ...)
	end,
	insert_notick = function(...)
		return buff_insert(false, ...)
	end,
	get = buff_get,
	remove = buff_remove,

	tick = buff_tick,
	defer = buff_defer,
}
