local util = require("util")
local hexagon = require("hexagon")


local priority = {
	first = 1,
	stat = 2,
	post_stat = 3,
	damage = 4,
	shield = 5,
	last = 6,
}

local function common_tick(obj)
	if obj.duration then
		if obj.duration <= 0 then
			return false
		else
			obj.duration = obj.duration - 1
		end
	elseif obj.remain then
		obj.remain = math.max(obj.remain - 1, 0)
	else
		error(obj)
	end
	return true
end

local function skill_update(skill, tick)
	local entity = skill.owner
	local enable = true

	if entity.status.down then
		enable = false
		tick = false
	end

	if entity.status.ultimate then
		enable = false
	end

	if entity.status.block and not skill.noblock then
		enable = false
	end

	if tick then
		common_tick(skill)
	end
	skill.enable = enable
	return enable
end

local function energy_shield(damage, energy, ratio)
	ratio = ratio or 1
	local cap = energy * ratio
	if damage.damage <= cap then
		return math.floor(energy - damage.damage / ratio)
	else
		damage.damage = damage.damage - cap
		return 0, damage
	end
end

local function hook(entity, hook)
	table.insert(entity.damage_hook, util.copy_table(hook))
	return true
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

local function damage(entity, damage)
	if entity.status.fly and damage.type == "ground" then
		return nil
	end
	if not entity.status.fly and damage.type == "air" then
		return nil
	end

	damage = util.copy_table(damage)
	for i = 1, #entity.hook, 1 do
		damage = entity.hook[i]:func(entity, damage)
		if not damage then
			return nil
		end
	end

	local resist = entity.resistance[damage.element] or 0
	local val = damage.damage * (1 - resist)

	if damage.element == "mental" then
		entity.sanity = math.max(0, math.floor(entity.sanity - val))
	else
		entity.health = math.floor(entity.health - val)
	end
	local killed = false
	if not entity:alive() then
		entity.map:remove(entity)
		killed = true
	end
	return val, killed
end

local function tick(entity)
	if not entity.status.down then
		entity.energy = math.floor(math.min(entity.energy_cap, entity.energy + entity.generator))
		for k, v in pairs(entity.inventory) do
			v:tick()
		end
		for k, v in pairs(entity.skills) do
			v:update(true)
		end
		entity.active = true
	else
		entity.active = false
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

local function new_entity(name, template)
	return {
		name = name,
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

local function new_character(name, template, skills)
	local obj = util.merge_table(new_entity(name, template), {
		creature = true,
		status = {},
		energy = template.generator,
		sanity = 100,
		inventory = {},
		skills = {},
		active = true,
		tick = tick,
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
	common_tick = common_tick,
	skill_update = skill_update,
	energy_shield = energy_shield,
	hook = hook,
	move = move,
	teleport = teleport,
	heal = heal,
	damage = damage,
	new_entity = new_entity,
	new_character = new_character,
}
