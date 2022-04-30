local util = require("util")
local hexagon = require("hexagon")

local priority = {
	-- common --
	first = 0,
	last = 65535,

	-- buff --
	ultimate = 1,
	down = 2,
	pre_stat = 10,
	block = 13,
	fly = 14,
	drown = 15,
	stat = 20,
	post_stat = 40,
	damage = 100,

	-- hook --
	shield = 10,
	bubble = 20,
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
	end
	return true
end

local function skill_update(skill)
	local entity = skill.owner
	local enable = true

	if entity.status.down then
		enable = false
	end

	if entity.status.ultimate and not entity.free_ultimate then
		enable = false
	end

	if skill.power_req and entity.power < skill.power_req then
		enable = false
	end

	skill.enable = enable
	return enable
end


local function shield(damage, strength, ratio)
	local dmg = damage.damage
	local req = dmg * (ratio or 1)
	local blk = math.floor(math.min(req, strength))

	log("shield blocked " .. blk .. " damage")

	if blk >= dmg then
		return strength - blk
	else
		damage.damage = dmg - blk
		return strength - blk, damage
	end
end

local function weaken(entity, value, ratio)
	for k, v in pairs(entity.resistance) do
		if v > 0 then
			local l = v - value
			if ratio then
				l = math.min(l, v * ratio)
			end
			entity.resistance[k] = math.max(0, l)
		end
	end
end

local function strengthen(entity, value, top)
	for k, v in pairs(entity.resistance) do
		entity.resistance[k] = math.min(v + value, top or 1)
	end
end

local function multi_target(skill, target_list, unique)
	if not target_list or #target_list < 1 or #target_list > skill.shots then
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
	if entity.health >= entity.health_cap then
		return 0
	end
	local val = heal.heal or heal.ratio * entity.health_cap
	if heal.max_cap then
		val = math.min(val, heal.max_cap)
	end
	val = math.floor(math.max(val, heal.min_cap or 0))

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
			if not damage or damage.damage == 0 then
				return nil
			end
		end
		local resist = entity.resistance[damage.element] or 0
		val = damage.damage * (1 - resist)
	end
	if damage.damage == 0 then
		return
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
		entity.map:kill(entity)
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
			v.remain = math.max(v.remain - 1, 0)
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
		immune = {},

		alive = function(self)
			return self.health > 0
		end,

	}, template)
end

local function new_character(name, template, skills, fixed_buff)
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

	if fixed_buff then
		for i = 1, #fixed_buff, 1 do
			local b = util.copy_table(fixed_buff[i])
			b.owner = obj
			table.insert(obj.buff, b)
		end
	end

	return obj
end

return {
	priority = priority,
	log = log,
	log_level = log_level,
	common_tick = common_tick,
	skill_update = skill_update,
	shield = shield,
	weaken = weaken,
	strengthen = strengthen,
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
