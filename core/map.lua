local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

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
		obj = require("base/" .. name)(...)
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
--[[
local function tick(self, tid, round)
	if self.teams[tid] and self.teams[tid].round_start then
		self.teams[tid].round_start(self, tid, round)
	end

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

	local res = true
	if self.teams[tid] and self.teams[tid].round then
		res = self.teams[tid].round(self, tid, round)
	end

	buff.defer(self:get_team(tid))

	if self.teams[tid] and self.teams[tid].round_end then
		self.teams[tid].round_end(self, tid, round)
	end

	return res
end

local function run(self)
	local round = 0
	while true do
		round = round + 1
		tick(self, 0, round)
		for i = 1, #self.teams, 1 do
			if not tick(self, i, round) then
				return
			end
		end
	end
end
--]]

local function round_start(tid)
	if self.teams[tid] and self.teams[tid].round_start then
		self.teams[tid].round_start(self, tid, round)
	end

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

	if self.teams[tid] and self.teams[tid].round then
		return self.teams[tid].round(self, tid, round)
	end
end

local function round_end(tid)
	buff.defer(self:get_team(tid))

	if self.teams[tid] and self.teams[tid].round_end then
		self.teams[tid].round_end(self, tid, round)
	end
end

local function event(self, obj, cmd, ...)
	-- local tid = obj.team
	-- local func = self.teams[tid][cmd]
	local func = self.event_table[cmd]
	if func then
		func(self, obj, ...)
	end
end

return function(map_info)
	local map = {
		scale = map_info.scale,
		event_table = map_info.event_table,
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
		round_start = round_start,
		round_end = round_end,
		event = event,
	}

	event(map, map, "new_map")

	for i, v in ipairs(map_info.layers) do
		local l = require("base/layer_" .. v.name)(map, v)
		map.layers[i] = l
		map.layer_map[v.name] = l
	end

	for i, t in ipairs(map_info.teams) do
		local tid = new_team(map, t)

		for i, e in ipairs(t) do
			spawn(map, tid, e[1], e[2], table.unpack(e, 3))
		end
	end

	return map
end


