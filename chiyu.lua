local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local template = {
	health_cap = 700,
	speed = 7,
	accuracy = 9,
	power = 200,
	sight = 3,
	energy_cap = 1000,
	generator = 100,
	moved = false,
	resistance = {
		physical = 0.2,
		file = 0.9,
		water = -0.2,
		air = 0,
		earth = 0.2,
		star = 0,
		mental = 0.4,
	},
	immune = {
		burn = true,
	},
	quiver = {
		name = "fire",
		cost = 30,
		single = function(entity, target)
			entity.map:damage(entity.team, { target }, {
				damage = 100,
				element = "fire",
			}, buff, "burn", 2)
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "fire",
			})

			entity.map:effect(entity.team, area, "flame", 1)
		end,
	},
}

local buff_curse = {
	name = "curse_of_phoenix",
	priority = core.priority.last,
	tick = function(self)
		local entity = self.owner
		local t = entity.inventory[1].temperature
		local cooling = 4
		if entity.status.cooling then
			cooling = cooling + 1
		end
		if entity.status.wet then
			cooling = cooling * 2
			entity.power = entity.power * 0.8
		end

		t = math.max(0, t - cooling)
		entity.inventory[1].temperature = t
		entity.power = entity.power * (1 + 0.1 * (t // 10))
		if t > 40 then
			core.damage(entity, {
				damage = (t - 40) // 4,
				element = "mental",
				real = true,
			})
			core.damage(entity, {
				damage = (entity.health_cap // 100) * (t - 40) // 4,
				element = "fire",
				real = true,
			})
		end

		return true
	end,
}

local function ember_damage(entity, ...)
	local count, killed = entity.map:damage(entity.team, ...)
	for k, v in pairs(killed) do
		core.heal(entity, math.min(v // 10, entity.health_cap // 20))
	end
	local ember = entity.inventory[1]
	ember.temperature = ember.temperature + count * 3 + #killed * 8
	return count
end

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 10,
	step = 2,

	update = function(self, tick)
		local entity = self.owner
		self.enable = core.skill_update(self, tick) and not entity.moved
	end,
	use = function(self, waypoint)
		local entity = self.owner

		if #waypoint == 0 or #waypoint > self.step then
			return false
		end

		local res = core.move(entity, waypoint)
		if res then
			entity.moved = true
		end

		return res
	end,
}

local skill_attack = {
	name = "attack",
	type = "direction",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 40,

	update = core.skill_update,
	use = function(self, direction)
		local entity = self.owner

		local target = hexagon.direction(entity.pos, direction)
		local res = ember_damage(entity, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		})
		if res > 0 then
			ember_damage(entity, { target }, {
				damage = entity.power / 2,
				element = "fire",
			}, buff, "burn", 1)
		end
		return true
	end,
}

local skill_charge = {
	name = "charge",
	type = "line",
	cooldown = 3,
	remain = 0,
	enable = true,
	cost = 300,
	range = {2, 5},

	update = core.skill_update,
	use = function(self, direction, distance)
		local entity = self.owner

		if distance < self.range[1] or distance > self.range[2] then
			return false
		end

		local line = hexagon.fan(entity.pos, distance, direction, direction)

		local res = core.teleport(entity, line[#line])
		if res then
			ember_damage(entity, line, {
				damage = entity.power,
				element = "fire",
			}, buff, "burn", 1)

			ember_damage(entity, { line[#line - 1] }, {
				damage = entity.power * 2,
				element = "physical",
				accuracy = entity.accuracy,
			}, buff, "down", 1)
		end

		return res
	end,
}

local skill_ignition = {
	name = "ignition",
	type = "target",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 200,
	range = { 1, 4 },

	update = function(self, tick)
		local entity = self.owner
		self.enable = core.skill_update(self, tick) and (entity.inventory[2].remain == 0)
	end,
	use = function(self, target)
		local entity = self.owner

		local dis = hexagon.distance(entity.pos, target, self.range[2])
		if not dis or dis < self.range[1]  then
			return false
		end

		local seed = {
			name = "fire",
			team = entity.team,
			power = entity.power,
			pos = target,
			range = 1,
		}

		seed = entity.map:contact(seed)
		if seed then
			local area = hexagon.range(seed.pos, seed.range)
			entity.map:damage(entity.team, area, {
				damage = seed.power,
				element = "fire",
			}, buff, "burn", 1)
			entity.map:effect(entity.team, area, "flame", 1)
		end

		local feather = entity.inventory[2]
		feather.remain = feather.cooldown

		return true
	end,
}

local skill_sweep = {
	name = "sweep",
	type = "direction",
	cooldown = 3,
	remain = 0,
	enable = true,
	cost = 200,

	update = core.skill_update,
	use = function(self, direction)
		local entity = self.owner

		local area = hexagon.fan(entity.pos, 1, direction + 5, direction + 7)
		ember_damage(entity, area, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		})

		local area = hexagon.fan(entity.pos, 2, direction + 5, direction + 7)
		ember_damage(entity, area, {
			damage = entity.power,
			element = "fire",
		}, buff, "burn", 1)

		return true
	end,
}

local skill_nirvana = {
	name = "nirvana",
	type = "target",
	cooldown = 10,
	remain = 0,
	enable = false,
	cost = 0,

	update = function(self, tick)
		local entity = self.owner
		self.enable = core.skill_update(self, tick) and (entity.health / entity.health_cap < 0.2)
	end,
	use = function(self, target)
		local entity = self.owner

		local area = hexagon.range(entity.pos, 1)

		local res = core.teleport(entity, target)
		if res then
			entity.map:effect(entity.team, area, "flame", 0)
		end

		return res
	end,
}

local skill_phoenix = {
	name = "phoenix",
	type = "line",
	cooldown = 12,
	remain = 0,
	enable = true,
	cost = 800,

	update = function(self, tick)
		local entity = self.owner
		self.enable = core.skill_update(self, tick) and (entity.inventory[2].remain == 0)
	end,
	use = function(self, direction, distance)
		local entity = self.owner

		if distance <= 0 then
			return false
		end

		local main = hexagon.fan(entity.pos, distance, direction, direction)
		local sides = util.append_table(
			hexagon.fan(hexagon.direction(entity.pos, direction + 5), distance, direction, direction),
			hexagon.fan(hexagon.direction(entity.pos, direction + 7), distance, direction, direction))
		table.insert(sides, hexagon.direction(main[#main], direction))

		local res = core.teleport(entity, main[#main])
		if res then
			ember_damage(entity, main, {
				damage = entity.power * 2,
				element = "fire",
			}, buff, "burn", 2)

			ember_damage(entity, sides, {
				damage = entity.power,
				element = "fire",
			}, buff, "burn", 2)

			ember_damage(entity, { main[#main - 1] }, {
				damage = entity.power * 2,
				element = "fire",
			})

			ember_damage(entity, { main[#main - 1] }, {
				damage = entity.power * 2,
				element = "physical",
			}, buff, "down", 2)

			local area = util.append_table(main, sides)
			entity.map:effect(entity.team, area, "flame", 2)

			local feather = entity.inventory[2]
			feather.remain = feather.cooldown
		end

		return res
	end,
}

return function()
	local chiyu = core.new_character("chiyu", template, {
		skill_move,
		skill_attack,
		skill_charge,
		skill_ignition,
		skill_sweep,
		skill_nirvana,
		skill_phoenix,
	})
	table.insert(chiyu.inventory, {
		name = "ember",
		temperature = 0,
		tick = function(self)
		end,
	})
	table.insert(chiyu.inventory, {
		name = "feather",
		cooldown = 5,
		remain = 0,
		tick = core.common_tick,
	})

	buff(chiyu, buff_curse)

	return chiyu
end
