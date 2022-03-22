local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local template = {
	health_cap = 600,
	speed = 1,
	dodge = 0.1,
	accuracy = 0.2,
	power = 1000,
	sight = 2,
	energy_cap = 1000,
	generator = 100,
	resistance = {
		physical = 0.6,
		fire = 0.8,
		water = 0.4,
		air = 0.8,
		earth = 0.9,
		star = 0.3,
		mental = 0.7,
	},

	hook = {{
		priority = core.priority.last,
		func = function(self, entity, damage)
			if entity.inventory[1]:get() ~= "shield" or entity.status.ultimate then
				return damage
			end

			-- shield has 75% resistance, absorb 2 damage using 1 energy
			entity.energy, damage = core.energy_shield(damage, entity.energy, 8)

			return damage
		end,
		}},

	quiver = {
		name = "earth",
		cost = 60,
		range = 5,
		single = function(entity, target)
			entity.map:damage(entity.team, { target }, {
				damage = entity.power * 2,
				element = "earth",
			})
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "earth",
			})
		end,
	},
}

local buff_shelter = {
	name = "shelter",
	priority = core.priority.shield,
	tick = function(self)
		local entity = self.owner
		if entity.energy <= 0 or not entity.shelter then
			return false
		end
		entity.status.shelter = true
		entity.generator = entity.generator * 2
		return true
	end,
	defer = function(self)
		local entity = self.owner
		if not entity.shelter then
			return
		end
		local list = entity.map:get_area(hexagon.range(entity.pos, 1))
		for k, e in pairs(list) do
			if e.team == entity.team then
				core.hook(e, {
					priority = core.priority.shield,
					origin = entity,
					func = function(self, entity, damage)
						if not self.holder.status.shelter then
							return damage
						end

						local origin = self.origin
						-- shield has 75% resistance, absorb 1 damage using 1 energy
						origin.energy, damage = core.energy_shield(damage, origin.energy, 4)
						return damage
					end
				})
			end
		end
	end,
}

local buff_final_guard = {
	name = "final_guard",
	priority = core.priority.first,
	duration = 4,
	tick = function(self)
		local entity = self.owner
		if not core.common_tick(self) then
			return false
		end
		local list = entity.map:get_team(entity.team)
		for k, e in pairs(list) do
			core.hook(e, {
				priority = core.priority.shield,
				origin = entity,
				func = function(self, entity, damage)
					local origin = self.origin

					-- shield has 50% resistance, absorb 1 damage using 1 energy or 1 health
					origin.energy, damage = core.energy_shield(damage, origin.energy, 2)
					if damage then
						damage.type = nil
						core.damage(origin, damage)
					end
					return nil
				end
			})
		end
		entity.status.ultimate = true
		entity.generator = 0
		for k, v in pairs(entity.resistance) do
			entity.resistance[k] = math.min(v, 0.2)
		end
		return true
	end,
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 40,
	step = 1,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()
		if mode == "shield" then
			self.cost = 80
		else
			self.cost = 40
		end

		self.enable = core.skill_update(self, tick) and not entity.status.shelter
	end,
	use = function(self, waypoint)
		local entity = self.owner

		if #waypoint == 0 or #waypoint > self.step then
			return false
		end

		return core.move(entity, waypoint)
	end,
}

local skill_attack = {
	name = "smash",
	type = "direction",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 300,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		self.enable = core.skill_update(self, tick) and mode ~= "shield"
	end,
	use = function(self, direction)
		local entity = self.owner
		local target = hexagon.direction(entity.pos, direction)
		entity.map:damage(entity.team, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
			type = "ground",
		}, "down", 1)

		local splash = hexagon.range(target, 1)

		entity.map:damage(entity.team, splash, {
			damage = entity.power / 10,
			element = "earth",
		})

		return true
	end,
}

local skill_transform = {
	name = "transform",
	type = "toggle",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,

	update = function(self, tick)
		local entity = self.owner

		if entity.status.shelter then
			self.cooldown = 1
		else
			self.cooldown = 0
		end

		core.skill_update(self, tick)
	end,

	use = function(self)
		local entity = self.owner
		entity.inventory[1]:next()
		entity.shelter = nil
		return true
	end,
}

local skill_cannon = {
	name = "rock_cannon",
	type = "target",
	cooldown = 5,
	remain = 0,
	enable = true,
	cost = 500,

	range = { 2, 5 },

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		self.enable = core.skill_update(self, tick) and mode ~= "shield"
	end,
	use = function(self, target)
		local entity = self.owner

		local dis = hexagon.distance(entity.pos, target, self.range[2])
		if not dis or dis < self.range[1] then
			return false
		end

		entity.map:damage(entity.team, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		}, "down", 1)

		local splash = hexagon.range(target, 1)

		entity.map:damage(entity.team, splash, {
			damage = entity.power / 10,
			element = "earth",
		})

		return true
	end,
}

local skill_spike = {
	name = "spike",
	type = "direction",
	cooldown = 3,
	remain = 0,
	enable = false,
	cost = 200,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		self.enable = core.skill_update(self, tick) and mode == "shield"
	end,
	use = function(self, direction)
		local entity = self.owner

		local target = hexagon.fan(entity.pos, 2, direction + 5, direction + 7)
		entity.map:damage(entity.team, target, {
			damage = entity.power / 5,
			element = "earth",
			type = "ground",
		}, "block", 1)

		return true
	end,
}

local skill_shelter = {
	name = "shelter",
	type = "effect",
	cooldown = 8,
	remain = 0,
	enable = true,
	cost = 0,
	range = 1,
	noblock = true,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()
		local active = entity.status.shelter

		self.enable = core.skill_update(self, tick and not active) and mode == "shield" and not active
	end,
	use = function(self)
		local entity = self.owner

		entity.shelter = true
		buff(entity, buff_shelter)

		return true
	end,
}

local skill_final_guard = {
	name = "final_guard",
	type = "effect",
	cooldown = 20,
	remain = 0,
	enable = true,
	cost = 0,
	noblock = true,

	update = function(self, tick)
		local entity = self.owner
		local active = entity.status.ultimate

		self.enable = core.skill_update(self, tick and not active) and not entity.status.shelter
	end,
	use = function(self)
		local entity = self.owner

		entity.status.ultimate = true
		buff(entity, buff_final_guard)

		return true
	end,
}

return function()
	local shian = core.new_character("shian", template, {
		skill_move,
		skill_attack,
		skill_transform,
		skill_cannon,
		skill_spike,
		skill_shelter,
		skill_final_guard,
	})

	table.insert(shian.inventory, {
		name = "yankai",
		modes = { "hammer", "shield" },
		select = 1,
		tick = function(self)
		end,
		get = function(self)
			return self.modes[self.select]
		end,
		next = function(self)
			self.select = self.select % #self.modes + 1
		end,

	})

	shian.alive = function(self)
		return self.health > 0 or self.status.final_guard
	end
	return shian
end
