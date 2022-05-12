local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

local function new_team(self, ...)
	table.insert(self.teams, table.pack(...))
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

local function damage(self, team, area, damage, func, ...)
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

local function heal(self, team, area, heal, func, ...)
	for k, p in pairs(area) do
		local e = self:get(p)
		if e and e.team == team then
			core.heal(e, heal)
			if func then
				func(e, ...)
			end
		end
	end
end

local function spawn(self, team, name, pos)
	if self:get(pos) then
		return nil
	end
	local obj
	if type(name) == "string" then
		obj = require(name)()
	else
		obj = name()
	end

	obj.map = self
	obj.team = team
	obj.pos = pos

	table.insert(self.entities, obj)
	return obj
end

local function kill(self, obj)
	for k, v in pairs(self.entities) do
		if v == obj then
			if obj.death then
				obj:death()
			end
			table.remove(self.entities, k)
			return true
		end
	end
	return false
end

local function contact(self, seed)
	local step = seed.step or 0x10
	while step > 0 do
		core.log(seed.name .. " contact " .. hexagon.print(seed.pos))
		local orig_pos = seed.pos
		local moved = false
		for i = 1, #self.layers, 1 do
			local seed = self.layers[i]:contact(seed)
			if not seed then
				return nil
			end
			if not hexagon.cmp(seed.pos, orig_pos) then
				core.log(seed.name .. " moved to " .. hexagon.print(seed.pos))
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
			e[k] = v
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

	if tid > 0 then
		local ctrl = self.teams[tid]
		if type(ctrl[1]) == "function" then
			ctrl[1](self, tid, table.unpack(ctrl, 2))
		end
	end

	buff.defer(self:get_team(tid))
end

local function run(self)
	while true do
		tick(self, 0)
		for i = 1, #self.teams, 1 do
			tick(self, i)
		end
	end
end

return function(scale, layer_list)
	local map = {
		scale = scale,
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
	}

	for i = 1, #layer_list, 1 do
		local n = layer_list[i]
		local l = require("layer_" .. n)(map)
		map.layers[i] = l
		map.layer_map[n] = l
	end

	return map
end


