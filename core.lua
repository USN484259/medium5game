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

	if blk >= dmg then
		return blk
	else
		damage.damage = dmg - blk
		return blk, damage
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
		pos = hexagon.direction(pos, waypoint[i])
		if pos[1] > map.scale or map:get(pos) then
			return false
		end
	end
	map:ui(entity, "move", waypoint)
	entity.pos = pos
	return true
end

local function teleport(entity, target)
	local map = entity.map
	if target[1] > map.scale or map:get(target) then
		return false
	end
	map:ui(entity, "teleport", target)
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

	map:ui(entity, "heal", val)
	entity.health = math.floor(entity.health + val)
	return val
end

local function miss(speed, accuracy)
	local val = util.random("raw")
	-- log("accuracy/speed " .. accuracy .. '/' .. speed .. " rng " .. string.format("0x%X", val))
	val = (val ~ (val >> 4)) & 0x0F
	return val >= (8 + (accuracy - speed) * 2)
end

local function damage(entity, damage)
	if entity.status.fly and damage.type == "ground" then
		return nil
	end
	if not entity.status.fly and damage.type == "air" then
		return nil
	end
	if damage.accuracy and miss(entity.speed or 0, damage.accuracy) then
		entity.map:ui(entity, "miss")
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
	if val == 0 then
		return
	end

	entity.map:ui(entity, "damage", val, damage.element)
	if damage.element == "mental" then
		entity.sanity = math.max(0, math.floor(entity.sanity - val))
	else
		entity.health = math.floor(entity.health - val)
	end
	if not entity:alive() then
		entity.map:kill(entity)
		return val, entity.health_cap
	end
	return val
end

local function generate(entity, power)
	entity.map:ui(entity, "generate", power)
	entity.energy = math.floor(math.min(entity.energy_cap, entity.energy + power))
end

local function tick(entity)
	if not entity.status.down then
		if entity.generator then
			generate(entity, entity.generator)
		end
		for k, v in pairs(entity.inventory) do
			v:tick()
		end

		for k, v in pairs(entity.skills) do
			v.remain = math.max(v.remain - 1, 0)
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
		entity.map:ui(entity, "skill", skill)

		skill.remain = skill.cooldown
		entity.energy = entity.energy - cost
		entity.active = nowait
	end

	return res
end

local function new_entity(name, template)
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
