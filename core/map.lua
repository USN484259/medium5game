local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

local function new_team(self, handler)
	table.insert(self.teams, handler or {})
	return #self.teams
end

local function layer_get(self, layer, ...)
	return self.layer_map[layer]:get(...)
end

local function layer_set(self, layer, ...)
	return self.layer_map[layer]:set(...)
end

local function get(self, pos)
	for k, e in pairs(self.entities) do
		if hexagon.cmp(pos, e.pos) then
			return e
		end
	end
end

local function get_area(self, area)
	local list = {}
	for k, v in pairs(area) do
		local e = self:get(v)
		if e then
			table.insert(list, e)
		end
	end
	return list
end

local function get_team(self, team)
	local list = {}
	for k, e in pairs(self.entities) do
		if e.team == team then
			table.insert(list, e)
		end
	end
	return list
end

local function damage(self, src, area, damage, func, ...)
	damage = util.copy_table(damage)

	if damage.ratio then
		damage.damage = damage.ratio * src.power
	end
	if damage.accuracy and type(damage.accuracy) ~= "number" then
		damage.accuracy = src.accuracy
	end

	local team = 0
	if src then
		team = src.team
	end

	local count = 0
	local killed = {}
	for k, p in pairs(area) do
		local e = self:get(p)
		if e and (team == 0 or e.team ~= team) then
			local d, k = core.damage(e, damage)
			if d then
				count = count + 1
				if func then
					func(e, ...)
				end
			end
			if k then
				table.insert(killed, k)
			end
		end
	end
	return count, killed
end

local function heal(self, src, area, heal, func, ...)
	for k, p in pairs(area) do
		local e = self:get(p)
		if e and e.team == src.team then
			local val

			if heal.src_ratio then
				val = src.power * heal.src_ratio
			elseif heal.dst_ratio then
				val = e.health_cap * heal.dst_ratio
			else
				val = heal.heal or 0
			end

			if heal.max_cap then
				val = math.min(val, heal.max_cap)
			end
			if heal.min_cap then
				val = math.max(val, heal.min_cap)
			end

			core.heal(e, val, heal.overcap)
			if func then
				func(e, ...)
			end
		end
	end
end

local function spawn(self, team, name, pos, ...)
	if self:get(pos) then
		return nil
	end
	local obj
	if type(name) == "string" then
		obj = require(name)(...)
	else
		obj = name(...)
	end

	obj.map = self
	obj.team = team
	obj.pos = pos

	table.insert(self.entities, obj)
	self:event(obj, "spawn")

	return obj
end

local function kill(self, obj)
	for k, v in pairs(self.entities) do
		if v == obj then
			if obj.death then
				obj:death()
			end
			table.remove(self.entities, k)
			self:event(obj, "kill")
			return true
		end
	end
	return false
end

local function contact(self, seed)
	local step = seed.step or 0x10
	while step > 0 do
		local orig_pos = seed.pos
		local moved = false
		for i = 1, #self.layers, 1 do
			local seed = self.layers[i]:contact(seed)
			if not seed then
				return nil
			end
			if not hexagon.cmp(seed.pos, orig_pos) then
				self:event(seed, "seed", orig_pos)
				moved = true
				break
			end
		end
		if not moved then
			break
		end

		step = step - 1
	end

	return seed
end

local function tick(self, tid)
	-- layers tick
	for i = 1, #self.layers, 1 do
		self.layers[i]:tick(tid)
	end

	local team = self:get_team(tid)
	for k, e in pairs(team) do
		-- layers apply
		for i = 1, #self.layers, 1 do
			self.layers[i]:apply(e)
		end

		e.status = {}
		e.hook = {}
		e.immune = {}

		for k, v in pairs(e.template) do
			if type(v) == "table" then
				e[k] = util.copy_table(v)
			else
				e[k] = v
			end
		end
	end

	buff.tick(team)

	for k, e in pairs(team) do
		if not e:alive() then
			self:kill(e)
		elseif e.tick then
			e:tick()
		end
	end

	if tid > 0 and self.teams[tid].ui and not self.teams[tid].ui(self, tid) then
		return false
	end

	buff.defer(self:get_team(tid))
	return true
end

local function run(self)
	while true do
		tick(self, 0)
		for i = 1, #self.teams, 1 do
			if not tick(self, i) then
				return
			end
		end
	end
end

local function event(self, obj, cmd, ...)
	local tid = obj.team
	local func = self.teams[tid][cmd]
	if func then
		func(self, obj, ...)
	end
end

return function(map_info)
	local map = {
		scale = map_info.scale,
		layers = {},
		layer_map = {},
		teams = {},
		entities = {},
		new_team = new_team,
		layer_get = layer_get,
		layer_set = layer_set,
		get = get,
		get_area = get_area,
		get_team = get_team,
		damage = damage,
		heal = heal,
		contact = contact,
		spawn = spawn,
		kill = kill,
		run = run,
		event = event,
	}

	for i = 1, #map_info.layers, 1 do
		local layer_info = map_info.layers[i]
		local l = require("layer_" .. layer_info.name)(map, layer_info)
		map.layers[i] = l
		map.layer_map[layer_info.name] = l
	end

	for i = 1, #map_info.teams, 1 do
		local team_info = map_info.teams[i]
		local tid = new_team(map, team_info.ui)

		for j = 1, #team_info, 1 do
			local e = team_info[j]
			spawn(map, tid, e[1], e[2], table.unpack(e, 3))
		end
	end

	return map
end


