local util = require("util")
local hexagon = require("hexagon")


local priority = {
	first = 1,
	stat = 2,
	damage = 4,
	shield = 5,
	last = 6,
}

local function damage_to_hp(entity, damage)
	local ratio = entity.resistance[damage.element] or 0
	return damage.damage * (1 - ratio)
end

local function hp_to_damage(entity, hp, damage)
	local ratio = entity.resistance[damage.element] or 0
	if ratio == 1 then
		return nil
	end
	return util.merge_table(damage, {
		damage = hp / (1 - ratio)
	})
end

local function add_buff(entity, buff)
	table.insert(entity.buff, util.merge_table(util.copy_table(buff), {
		owner = entity
	}))
	return true
end

local function add_damage_hook(entity, hook)
	table.insert(entity.damage_hook, util.copy_table(hook))
	return true
end

local function for_area(entity, target, func, ...)
	local map = entity.map
	local count = 0
	local sum = 0
	for i = 1, #target, 1 do
		local e = map:get(target[i])
		if e then
			local res = func(e, ...)
			if res then
				count = count + 1
			end
			if type(res) == "number" then
				sum = sum + res
			end
		end
	end
	return count, sum
end

local function for_team(entity, func, ...)
	local map = entity.map
	local count = 0
	local sum = 0
	for k, v in pairs(map.entities) do
		if v.team == entity.team then
			local res = func(v, ...)
			if res then
				count = count + 1
			end
			if type(res) == "number" then
				sum = sum + res
			end
		end
	end
	return count, sum
end

local function move(entity, waypoint)
	local map = entity.map
	local pos = entity.pos
	for i = 1, #waypoint, 1 do
		pos = hexagon.direction(pos, waypoint[i])
		if pos[1] >= map.scale then
			return false
		end

		if map:get(pos) then
			return false
		end
	end
	entity.pos = pos
	return true
end

local function heal(entity, target, heal)
	return for_area(entity, target, function(entity, source, heal)
		if entity.team ~= source.team then
			return nil
		end
		
		for i = 1, #entity.heal_hook, 1 do
			heal = entity.damage_hook[i]:func(entity, source, heal)
			if not heal then
				return 0
			end
		end

		heal = math.max(0, math.min(heal, entity.health_cap - entity.health))

		entity.health = math.floor(entity.health + heal)
		return heal
	end, entity, heal)
end

local function damage(entity, target, damage)
	return for_area(entity, target, function(entity, source, damage)
		if entity.team == source.team then
			return nil
		end
		damage = util.copy_table(damage)
		for i = 1, #entity.damage_hook, 1 do
			damage = entity.damage_hook[i]:func(entity, source, damage)
			if not damage then
				return 0
			end
		end
		local val = damage_to_hp(entity, damage)
		entity.health = math.floor(entity.health - val)

		return val
	end, entity, damage)
end

local function new_entity(name, team, pos, template)
	return {
		name = name,
		pos = pos,
		team = team,
		template = template,

		health = template.health_cap,
		buff = {},
--[[
		on_damage = function(self, val, element)
			local ratio = 1 - (self.resistance[element] or 0)
			local damage = val * ratio
			if damage > 0 then
				self.health = self.health - val * ratio
				return true
			else
				return false
			end
		end,
--]]
		damage_hook = {},
		heal_hook = {},

		alive = function(self)
			return self.health > 0
		end,
		--[[
		update = function(self, tick)
			local new_buff = {}
			for k, v in pairs(template) do
				self[k] = v
			end
			table.sort(self.buff)
			for i = 1, #self.buff, 1 do
				if self.buff[i]:func(self, tick) then
					table.insert(new_buff, self.buff[i])
				end
			end

			self.buff = new_buff
		end,
		--]]

	}
end

local function new_character(name, team, pos, template, skills)
	local obj = util.merge_table(new_entity(name, team, pos, template), {
		status = {},
		energy = template.generator,
		sanity = 100,
		inventory = {},
		skills = {},
	})

	for i = 1, #skills, 1 do
		local sk = util.copy_table(skills[i])
		sk.owner = obj
		table.insert(obj.skills, sk)
	end

	return obj
end

return {
	priority = priority,
	damage_to_hp = damage_to_hp,
	hp_to_damage = hp_to_damage,
	add_buff = add_buff,
	add_damage_hook = add_damage_hook,
	for_area = for_area,
	for_team = for_team,
	move = move,
	heal = heal,
	damage = damage,
	new_entity = new_entity,
	new_character = new_character,
}
