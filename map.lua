local util = require("util")
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")
local fx = require("effect")

local function new_team(self, ...)
	table.insert(self.teams, table.pack(...))
	return #self.teams
end

local function layer(self, layer, ...)
	return self.layers[layer]:func(...)
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

local function effect(self, team, area, name, ...)
	for k, p in pairs(area) do
		local f = fx(name, ...)
		f.map = map
		f.team = team
		f.pos = p

		-- TODO reacts here

		table.insert(self.effects, f)
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

local function contact(self, obj)
	local step = obj.step or 0x10
	while step > 0 do
		local orig_pos = obj.pos
		local list = {}
		for k, v in pairs(self.effects) do
			if hexagon.cmp(v.pos, obj.pos) then
				table.insert(list, v)
			end
		end

		table.sort(list, function(a, b)
			return a.priority < b.priority
		end)

		for i = 1, #list, 1 do
			local f = list[i]
			if f.contact then
				f:contact(obj)
				if not hexagon.cmp(obj.pos, orig_pos) then
					break
				end
			end
		end

		if hexagon.cmp(obj.pos, orig_pos) then
			break
		end
		step = step - 1
	end
	return obj
end


local function tick_effect(self, team)
	local queue = {}
	for k, f in pairs(self.effects) do
		if f.team ~= team or core.common_tick(f) then
			table.insert(queue, f)
		end
	end
	self.effects = queue
end

local function tick(self, tid)
	tick_effect(self, tid)

	local team = self:get_team(tid)
	for k, e in pairs(team) do
		-- apply effects
		for k, f in pairs(self.effects) do
			if hexagon.cmp(f.pos, e.pos) and f.apply then
				f:apply(e)
			end
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
		teams = {},
		entities = {},
		effects = {},
		new_team = new_team,
		layer = layer,
		get = get,
		get_area = get_area,
		get_team = get_team,
		damage = damage,
		heal = heal,
		effect = effect,
		contact = contact,
		spawn = spawn,
		kill = kill,
		run = run,
	}

	for i = 1, #layer_list, 1 do
		local l = layer_list[i]
		map.layers[l] = require(l)(map)
	end

	return map
end


