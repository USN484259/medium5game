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

local do_log = false

local function log(str)
	if do_log then
		print(str)
	end
end

local function log_level(...)
	if select("#", ...) > 0 then
		do_log = select(1, ...)
	end
	return do_log
end

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
		log("shield blocked " .. damage.damage .. " damage")
		return math.floor(energy - damage.damage / ratio)
	else
		log("shield blocked " .. cap .. " damage")
		damage.damage = damage.damage - cap
		return 0, damage
	end
end

local function multi_target(skill, target_list, unique)
	if not target_list or #target_list < 1 then
		return false
	end
	for i = 1, #target_list, 1 do
		local tar = target_list[i]
		if type(skill.range) == "number" then
			if not hexagon.distance(skill.owner.pos, tar, skill.range) then
				return false
			end
		elseif type(skill.range) == "table" then
			local dis = hexagon.distance(skill.owner.pos, tar, skill.range[2])
			if not dis or dis < skill.range[1] then
				return false
			end
		end
		if unique then
			for j = 1, i - 1, 1 do
				if hexagon.cmp(tar, target_list[j]) then
					return false
				end
			end
		end
	end

	return true
end

local function hook(entity, hook)
	log(entity.name .. " add hook " .. hook.name)
	table.insert(entity.hook, util.copy_table(hook))
	table.sort(entity.hook, function(a, b)
		return a.priority < b.priority
	end)
	return true
end

local function move(entity, waypoint)
	local map = entity.map
	local pos = entity.pos
	for i = 1, #waypoint, 1 do
		local str = entity.name .. ' ' .. hexagon.print(pos)
		pos = hexagon.direction(pos, waypoint[i])
		str = str .. " ===> " .. hexagon.print(pos)
		if pos[1] > map.scale or map:get(pos) then
			log(str .. " blocked")
			return false
		end
		log(str)
	end
	entity.pos = pos
	return true
end

local function teleport(entity, target)
	local map = entity.map
	local str = entity.name .. ' ' .. hexagon.print(entity.pos) .. " |--> " .. hexagon.print(target)
	if target[1] > map.scale or map:get(target) then
		log(str .. " blocked")
		return false
	end
	log(str)
	entity.pos = target
	return true
end

local function heal(entity, heal)
	local val = heal.heal or heal.ratio * entity.health_cap
	val = math.floor(math.max(math.min(val, heal.max_cap), heal.min_cap))

	if not heal.overcap then
		local req = math.max(0, entity.health_cap - entity.health)
		val = math.max(req, val)
	end

	log(entity.name .. " gain " .. val .. " HP")
	entity.health = math.floor(entity.health + val)
	return val
end

local function miss(speed, accuracy)
	local val = util.random("raw")
	log("accuracy/speed " .. accuracy .. '/' .. speed .. " rng " .. string.format("0x%X", val))
	val = (val ~ (val >> 4)) & 0x0F
	return val >= (8 + (accuracy - speed) * 2)
end

local function damage(entity, damage)
	log(entity.name .. " get damage " .. damage.damage .. " of " .. damage.element)
	if entity.status.fly and damage.type == "ground" then
		return nil
	end
	if not entity.status.fly and damage.type == "air" then
		return nil
	end
	if damage.accuracy and miss(entity.speed or 0, damage.accuracy) then
		log("missed")
		return nil
	end
	local val
	if damage.real then
		val = damage.damage
	else
		damage = util.copy_table(damage)
		for i = 1, #entity.hook, 1 do
			damage = entity.hook[i]:func(entity, damage)
			if not damage then
				return nil
			end
		end
		local resist = entity.resistance[damage.element] or 0
		val = damage.damage * (1 - resist)
	end
	if damage.element == "mental" then
		log(entity.name .. " lose " .. val .. " sanity")
		entity.sanity = math.max(0, math.floor(entity.sanity - val))
	else
		log(entity.name .. " lose " .. val .. " HP")
		entity.health = math.floor(entity.health - val)
	end
	if not entity:alive() then
		log(entity.name .. " died")
		entity.map:remove(entity)
		return val, entity.health_cap
	end
	return val
end

local function generate(entity, power)
	log(entity.name .. " gain " .. power .. " energy")
	entity.energy = math.floor(math.min(entity.energy_cap, entity.energy + power))
end

local function tick(entity)
	if not entity.status.down then
		log(entity.name .. " ticking")
		generate(entity, entity.generator)
		for k, v in pairs(entity.inventory) do
			v:tick()
		end
		for k, v in pairs(entity.skills) do
			v:update(true)
		end
		entity.active = true
	else
		log(entity.name .. " is down, not ticked")
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

	log(entity.name .. " use skill " .. skill.name)
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
	log("spawned entity " .. name)
	return util.merge_table({
		name = name,
		template = template,
		health = template.health_cap,

		status = {},
		hook = {},
		buff = {},

		alive = function(self)
			return self.health > 0
		end,

	}, template)
end

local function new_character(name, template, skills)
	local obj = util.merge_table(new_entity(name, template), {
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
	log = log,
	log_level = log_level,
	common_tick = common_tick,
	skill_update = skill_update,
	energy_shield = energy_shield,
	multi_target = multi_target,
	hook = hook,
	move = move,
	teleport = teleport,
	heal = heal,
	damage = damage,
	generate = generate,
	new_entity = new_entity,
	new_character = new_character,
}
