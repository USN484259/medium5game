local util = require("util")
local hexagon = require("hexagon")


local priority = {
	first = 1,
	stat = 2,
	sanity = 3,
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
		if pos[1] >= map.scale or map:get(pos) then
			return false
		end
	end
	entity.pos = pos
	return true
end

local function teleport(entity, target)
	local map = entity.map
	if target[1] >= map.scale or map:get(target) then
		return false
	end
	entity.pos = target
	return true
end

local function heal(entity, heal)
	for i = 1, #entity.heal_hook, 1 do
		heal = entity.heal_hook[i]:func(entity, source, heal)
		if not heal then
			return 0
		end
	end

	heal = math.max(0, math.min(heal, entity.health_cap - entity.health))

	entity.health = math.floor(entity.health + heal)
	return heal
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

		if damage.element == "mental" then
			entity.sanity = math.max(0, math.floor(entity.sanity - val))
		else
			entity.health = math.floor(entity.health - val)
		end
		if not entity:alive() then
			source:killed(entity)
			entity.map:remove(entity)
		end
		return val
	end, entity, damage)
end

local function skill_update(skill, tick)
	if tick then
		skill.remain = math.max(skill.remain - 1, 0)
	end
end

local function action(entity, skill, ...)
	assert(entity == skill.owner)
	if not entity.active then
		return false
	end
	if not skill.enable or skill.remain > 0 then
		return false
	end

	local cost = skill.cost
	if skill.type == "waypoint" then
		cost = cost * #select(1, ...)
	end
	if entity.energy < cost then
		return false
	end

	local nowait = (skill.cooldown == 0)
	local res = skill:use(...)

	if res then
		skill.remain = skill.cooldown
		entity.energy = entity.energy - cost
		entity.active = nowait
	end

	return res
end

local function new_entity(name, team, pos, template)
	return {
		name = name,
		pos = pos,
		team = team,
		template = template,
		creature = false,
		health = template.health_cap,

		damage_hook = {},
		heal_hook = {},

		buff = {},

		alive = function(self)
			return self.health > 0
		end,
		killed = function(self, target)
		end,
	}
end

local function new_character(name, team, pos, template, skills)
	local obj = util.merge_table(new_entity(name, team, pos, template), {
		creature = true,
		status = {},
		energy = template.generator,
		sanity = 100,
		inventory = {},
		skills = {},
		active = true,
		action = action,
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
	teleport = teleport,
	heal = heal,
	damage = damage,
	skill_update = skill_update,
	new_entity = new_entity,
	new_character = new_character,
}
