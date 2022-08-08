local util = require("core/util")
local hexagon = require("core/hexagon")

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
	if obj.remain then
		obj.remain = math.max(obj.remain - 1, 0)
	elseif obj.duration then
		if obj.duration <= 0 then
			return false
		else
			obj.duration = obj.duration - 1
		end
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

	if skill.power_req and entity.power < entity.template.power * skill.power_req then
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
	map:event(entity, "move", waypoint)
	entity.pos = pos
	return true
end

local function teleport(entity, target)
	local map = entity.map
	if target[1] > map.scale or map:get(target) then
		return false
	end
	map:event(entity, "teleport", target)
	entity.pos = target
	return true
end

local function heal(entity, heal, overcap)
	if entity.health >= entity.health_cap then
		return 0
	end

	heal = math.floor(heal)

	if not overcap then
		local req = math.max(0, entity.health_cap - entity.health)
		heal = math.min(req, heal)
	end

	entity.map:event(entity, "heal", heal)
	entity.health = math.floor(entity.health + heal)
	return heal
end

local function miss(speed, accuracy)
	local val = util.random("raw") & 0xFF
	-- print("accuracy/speed " .. accuracy .. '/' .. speed .. " rng " .. string.format("0x%X", val))
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
		entity.map:event(entity, "miss")
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

	entity.map:event(entity, "damage", val, damage.element)
	if val then
		if damage.element == "mental" then
			entity.sanity = math.max(0, math.floor(entity.sanity - val))
		else
			entity.health = math.floor(entity.health - val)
		end
		if not entity:alive() then
			entity.map:kill(entity)
			return val, entity.health_cap
		end
	end
	return val
end

local function generate(entity, power)
	entity.map:event(entity, "generate", power)
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
	entity.moved = false
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

	entity.map:event(entity, "skill_init", skill)

	local nowait = (skill.cooldown == 0)
	local res = skill:use(...)

	if res then
		entity.map:event(entity, "skill_done", skill)

		skill.remain = skill.cooldown
		entity.energy = entity.energy - cost
		entity.active = nowait
	else
		entity.map:event(entity, "skill_fail", skill)
	end

	return res
end

local function new_entity(name, template)
	return util.merge_table({
		name = name,
		type = "entity",
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

local function new_character(name, template, skills, override)
	local obj = util.merge_table(new_entity(name, template), {
		type = "character",
		energy = template.generator,
		sanity = 100,
		inventory = {},
		skills = {},
		active = true,
		moved = false,
		tick = tick,
		action = action,
	})

	for i = 1, #skills, 1 do
		local sk = util.copy_table(skills[i])
		sk.owner = obj
		table.insert(obj.skills, sk)
	end

	if override then
		util.merge_table(obj, override)
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
