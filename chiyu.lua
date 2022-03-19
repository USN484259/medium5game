local util = require("util")
local hexagon = require("hexagon")
local core = require("core")

local template = {
	health_cap = 700,
	speed = 3,
	dodge = 0.4,
	accuracy = 0.9,
	power = 100,
	sight = 3,
	energy_cap = 1000,
	generator = 100,

	resistance = {
		physical = 0.2,
		file = 0.9,
		water = -0.2,
		wind = 0,
		earth = 0.2,
		star = 0,
		mental = 0.4,
	},

}

local buff_overkill = {
	name = "overkill",
	priority = core.priority.sanity,
	tick = function(self)
		local entity = self.owner

		if entity.kill_count > 1 then
			entity.sanity = entity.sanity - 2 ^ entity.kill_count
		end
		entity.kill_count = math.max(entity.kill_count - 1, 0)

		return true
	end,
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 20,
	step = 2,

	update = core.skill_update,
	use = function(self, waypoint)
		local entity = self.owner

		if #waypoint == 0 or #waypoint > self.step then
			return false
		end

		return core.move(entity, waypoint)

	end,
}

local skill_attack = {
	name = "attack",
	type = "direction",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 80,

	update = core.skill_update,
	use = function(self, direction)
		local entity = self.owner

		local target = hexagon.direction(entity.pos, direction)
		core.damage(entity, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		})
		core.damage(entity, { target }, {
			damage = entity.power,
			element = "fire",
			accuracy = entity.accuracy,
		})

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
			core.damage(entity, line, {
				damage = entity.power,
				element = "fire",
				accuracy = 1,
			})

			core.damage(entity, { line[#line - 1] }, {
				damage = entity.power * 2,
				element = "physical",
				accuracy = 1,
			})
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
		self.enable = (entity.inventory[1].remain == 0)
		return core.skill_update(self, tick)
	end,
	use = function(self, target)
		local entity = self.owner

		local dis = hexagon.distance(entity.pos, target, 2 * entity.map.scale)
		if dis < self.range[1] or dis > self.range[2] then
			return false
		end

		core.damage(entity, { target }, {
			damage = entity.power,
			element = "fire",
			accuracy = 1,
		})
		local splash = hexagon.range(target, 1)

		core.damage(entity, splash, {
			damage = entity.power / 2,
			element = "fire",
			accuracy = 1,
		})

		local feather = entity.inventory[1]
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

		local target = hexagon.fan(entity.pos, 1, direction + 5, direction + 7)
		core.damage(entity, target, {
			damage = entity.power,
			element = "physical",
			accuracy = 1,
		})

		target = hexagon.fan(entity.pos, 2, direction + 5, direction + 7)
		core.damage(entity, target, {
			damage = entity.power,
			element = "fire",
			accuracy = 1,
		})

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
		self.enable = (entity.health / entity.health_cap < 0.2)

		return core.skill_update(self, tick)
	end,
	use = function(self, target)
		local entity = self.owner

		local split = hexagon.range(entity.pos, 1)

		local res = core.teleport(entity, target)
		if res then
			core.damage(entity, split, {
				damage = entity.power / 4,
				element = "fire",
				accuracy = 1,
			})
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
		self.enable = (entity.inventory[1].remain == 0)
		return core.skill_update(self, tick)
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
			core.damage(entity, main, {
				damage = entity.power * 2,
				element = "fire",
				accuracy = 1,
			})

			core.damage(entity, sides, {
				damage = entity.power,
				element = "fire",
				accuracy = 1,
			})

			core.damage(entity, { main[#main - 1] }, {
				damage = entity.power * 2,
				element = "fire",
				accuracy = 1,
			})
			core.damage(entity, { main[#main - 1] }, {
				damage = entity.power * 2,
				element = "physical",
				accuracy = 1,
			})

			local feather = entity.inventory[1]
			feather.remain = feather.cooldown
		end

		return res
	end,
	
}

return function(team, pos)
	local chiyu = core.new_character("chiyu", team, pos, template, {
		skill_move,
		skill_attack,
		skill_charge,
		skill_ignition,
		skill_sweep,
		skill_nirvana,
		skill_phoenix,
	})

	table.insert(chiyu.inventory, {
		name = "feather",
		cooldown = 5,
		remain = 0,
		tick = function(self)
			self.remain = math.max(self.remain - 1, 0)
		end,
		get = function(self)
			return self.name .. '\t' .. self.remain .. '/' .. self.cooldown
		end,
	})

	chiyu.kill_count = 0
	chiyu.killed = function(self, target)
		local heal = math.min(target.health_cap / 20, self.health_cap / 10)
		core.heal(self, heal)
		self.kill_count = self.kill_count + 1
	end

	core.add_buff(chiyu, buff_overkill)

	return chiyu
end
