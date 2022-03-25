local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local template = {
	health_cap = 600,
	speed = 2,
	accuracy = 2,
	power = 1000,
	sight = 2,
	energy_cap = 1000,
	generator = 100,
	resistance = {
		physical = 0.6,
		fire = 0.7,
		water = 0.4,
		air = 0.8,
		earth = 0.8,
		star = 0.3,
		mental = 0.6,
	},
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

local buff_apple = {
	name = "apple",
	priority = core.priority.damage,
	duration = 4,
	tick = function(self)
		if not core.common_tick(self) then
			return false
		end
		local entity = self.owner
		if duration > 1 then
			entity.generator = entity.generator * 2
		end
		core.damage(entity, {
			damage = 5,
			element = "mental",
			real = true,
		})
		return true
	end,
}

local buff_shield = {
	name = "shield",
	priority = core.priority.shield,
	tick = function(self)
		return true
	end,
	defer = function(self)
		local entity = self.owner
		if entity.inventory[1]:get() ~= "shield" or entity.status.ultimate then
			return
		end
		local list = entity.map:get_area(hexagon.range(entity.pos, 1))
		for k, e in pairs(list) do
			if e.team == entity.team then
				core.hook(e, {
					name = "shield",
					priority = core.priority.shield,
					origin = entity,
					func = function(self, entity, damage)
						local origin = self.origin

						-- absorb 2 damage using 1 energy
						origin.energy, damage = core.energy_shield(damage, origin.energy, 2)
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
				name = "final_guard",
				priority = core.priority.shield,
				origin = entity,
				func = function(self, entity, damage)
					local origin = self.origin

					-- absorb 2 damage using 1 energy or 1 health
					origin.energy, damage = core.energy_shield(damage, origin.energy, 2)
					if damage then
						core.damage(origin, {
							damage = damage.damage / 2,
							element = damage.element,
							real = true,
						})
					end
					return nil
				end
			})
		end
		entity.status.ultimate = true
		entity.generator = 0

		return true
	end,
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 30,
	step = 1,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()
		if mode == "shield" then
			self.cost = 50
			self.cooldown = 2
		else
			self.cost = 30
			self.cooldown = 1
		end

		core.skill_update(self, tick)
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
	cooldown = 2,
	remain = 0,
	enable = true,
	cost = 200,

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		if mode == "hammer" then
			self.name = "smash"
			self.use = function(self, direction)
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
			end
		elseif mode == "shield" then
			self.name = "spike"
			self.use = function(self, direction)
				local entity = self.owner

				local target = hexagon.fan(entity.pos, 2, direction + 5, direction + 7)
				entity.map:damage(entity.team, target, {
					damage = entity.power / 5,
					element = "earth",
					type = "ground",
				}, "block", 1)

				return true
			end
		end

		core.skill_update(self, tick)
	end,
}

local skill_transform = {
	name = "transform",
	type = "toggle",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 0,

	update = core.skill_update,
	use = function(self)
		local entity = self.owner
		entity.inventory[1]:next()
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

		local res = entity.map:damage(entity.team, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		}, "down", 1)
		if res > 0 then
			-- extra damage to flying target
			entity.map:damage(entity.team, { target }, {
				damage = entity.power,
				element = "physical",
				type = "air",
			})
		end

		local splash = hexagon.range(target, 1)

		entity.map:damage(entity.team, splash, {
			damage = entity.power / 10,
			element = "earth",
		})

		return true
	end,
}

local skill_apple = {
	name = "apple",
	type = "effect",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,
	update = function(self, tick)
		local entity = self.owner
		self.enable = core.skill_update(self, tick) and (entity.inventory[2].remain == 0)
	end,
	use = function(self)
		local entity = self.owner

		core.generate(entity, 200)

		core.damage(entity, {
			damage = 10,
			element = "mental",
			real = true,
		})
		buff(entity, buff_apple)
		local apple = entity.inventory[2]
		apple.remain = apple.cooldown

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

		core.skill_update(self, tick and not active)
	end,
	use = function(self)
		local entity = self.owner

		entity.status.ultimate = true
		for k, v in pairs(entity.resistance) do
			entity.resistance[k] = math.min(0.2, v)
		end
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
		skill_apple,
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
	table.insert(shian.inventory, {
		name = "apple",
		cooldown = 5,
		remain = 0,
		tick = core.common_tick,
	})

	buff(shian, buff_shield)

	shian.alive = function(self)
		return self.health > 0 or self.status.ultimate
	end
	return shian
end
