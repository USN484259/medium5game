local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local template = {
	element = "earth",
	health_cap = 600,
	speed = 2,
	accuracy = 2,
	power = 800,
	sight = 2,
	energy_cap = 1000,
	generator = 100,
	resistance = {
		physical = 0.6,
		fire = 0.7,
		water = 0.4,
		air = 0.8,
		earth = 0.8,
		ether = 0.3,
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
	priority = core.priority.stat,
	duration = 4,
	tick = {{
		core.priority.pre_stat, function(self)
			local entity = self.owner
			if duration > 1 then
				entity.generator = entity.generator * 2
				entity.power = entity.power * 9 // 8
			end
			return true
		end
	}, {
		core.priority.damage, function(self)
			local entity = self.owner
			core.damage(entity, {
				damage = 5,
				element = "mental",
				real = true,
			})
			return true
		end
	}}
}

local buff_shield = {
	name = "shield",
	tick = {{
		core.priority.stat, function(self)
			local entity = self.owner
			if entity.inventory[1]:get() == "shield" and not entity.status.ultimate then
				entity.speed = math.floor(entity.speed / 2)
			end
			return true
		end,
	}},
	defer = {
		core.priority.first, function(self)
			local entity = self.owner
			if entity.inventory[1]:get() ~= "shield" or entity.status.down or entity.status.ultimate then
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
							local res
							-- absorb 2 damage using 1 energy
							res, damage = core.shield(damage, 2 * origin.energy)
							origin.energy = res // 2
							return damage
						end
					})
				end
			end
		end,
	}
}

local buff_final_guard = {
	name = "final_guard",
	duration = 4,

	tick = {{
		core.priority.ultimate, function(self)
			local entity = self.owner
			entity.status.ultimate = true
			entity.generator = 0
			entity.speed = 0
			for k, v in pairs(entity.resistance) do
				entity.resistance[k] = math.min(0.2, v)
			end

			local list = entity.map:get_team(entity.team)
			for k, e in pairs(list) do
				core.hook(e, {
					name = "final_guard",
					priority = core.priority.shield,
					origin = entity,
					func = function(self, entity, damage)
						local origin = self.origin
						local res
						-- absorb 2 damage using 1 energy or 1 health
						res, damage = core.shield(damage, 2 * origin.energy)
						origin.energy = res // 2

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

			return true
		end,
	}}
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 30,
	power_req = 200,
	step = 1,

	update = function(self)
		local entity = self.owner
		local mode = entity.inventory[1]:get()
		if mode == "shield" then
			self.cost = 50
			self.cooldown = 2
		else
			self.cost = 30
			self.cooldown = 1
		end

		core.skill_update(self)
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
	power_req = 400,

	update = function(self)
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
				}, buff.insert, "down", 1)

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
				}, buff.insert, "block", entity.power / 2, 1)

				return true
			end
		end

		core.skill_update(self)
	end,
}

local skill_transform = {
	name = "transform",
	type = "toggle",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 0,
	item = "yankai",

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
	power_req = 600,

	range = { 2, 5 },

	update = function(self)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		self.enable = core.skill_update(self) and mode ~= "shield"
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
		}, buff.insert, "down", 1)
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

	update = function(self)
		local entity = self.owner
		self.enable = core.skill_update(self) and (entity.inventory[2].remain == 0)
	end,
	use = function(self)
		local entity = self.owner

		core.generate(entity, 200)

		core.damage(entity, {
			damage = 10,
			element = "mental",
			real = true,
		})
		buff.insert(entity, buff_apple)
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

	update = core.skill_update,
	use = function(self)
		local entity = self.owner

		buff.insert(entity, buff_final_guard)

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


	shian.alive = function(self)
		return self.health > 0 or self.status.ultimate
	end

	buff.insert_notick(shian, buff_shield)

	return shian
end
