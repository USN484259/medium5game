local util = require("util")
local hexagon = require("hexagon")
local core = require("core")

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
		wind = 0.8,
		earth = 0.9,
		star = 0.3,
		mental = 0.7,
	},
	
	damage_hook = {
		{
			priority = core.priority.last,
			func = function(self, entity, source, damage)
				if entity.inventory[1].mode ~= "shield" or entity.status.final_guard then
					return damage
				end
				local val = core.damage_to_hp(entity, damage) / 2

				if entity.energy >= val then
					entity.energy = math.floor(entity.energy - val)
					return nil
				else
					val = val - entity.energy
					entity.energy = 0
					return core.hp_to_damage(entity, val, damage)
				end
			end,
		},
	},
	heal_hook = {
		priority = core.priority.first,
		func = function(self, entity, source, heal)
			if entity.status.final_guard then
				return nil
			else
				return heal
			end
		end,
	},
}

local buff_shelter = {
	name = "shelter",
	priority = core.priority.shield,
	tick = function(self)
		local entity = self.owner
		if entity.energy <= 0 or entity.status.insane then
			entity.status.shelter = nil
		end
		if not entity.status.shelter then
			return false
		end
		local range = hexagon.range(entity.pos, 1)
		core.for_area(entity, range, core.add_damage_hook, {
			priority = core.priority.shield,
			origin = entity,
			func = function(self, entity, source, damage)
				if not self.holder.status.shelter then
					return damage
				end
				local val = core.damage_to_hp(self.origin, damage)

				if self.origin.energy >= val then
					self.origin.energy = math.floor(self.origin.energy - val)
					return nil
				else
					val = val - self.origin.energy
					self.origin.energy = 0
					return core.hp_to_damage(self.origin, val, damage)
				end
			end
		})
		entity.generator = entity.generator * 2
		return true
	end,
}

local buff_final_guard = {
	name = "final_guard",
	priority = core.priority.first,
	duration = 4,
	tick = function(self)
		local entity = self.owner
		if self.duration <= 0 then
			entity.status.final_guard = nil
			return false
		end

		core.for_team(entity, core.add_damage_hook, {
			priority = core.priority.first,
			origin = entity,
			func = function(self, entity, source, damage)
				local val = core.damage_to_hp(self.origin, damage)

				if self.origin.energy >= val then
					self.origin.energy = math.floor(self.origin.energy - val)
				else
					val = val - self.origin.energy
					self.origin.energy = 0
					self.origin.health = math.floor(self.origin.health - val)
				end

				return nil
			end
		})
		entity.generator = 0
		self.duration = self.duration - 1
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
		self.enable = not (entity.status.final_guard or entity.status.shelter)

		local mode = entity.inventory[1].mode

		if mode == "shield" then
			self.cost = 80
		else
			self.cost = 40
		end

		if tick then
			self.remain = math.max(self.remain - 1, 0)
		end
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
		local mode = entity.inventory[1].mode

		self.enable = (mode ~= "shield" and not entity.status.final_guard)

		if tick then
			self.remain = math.max(self.remain - 1, 0)
		end
	end,
	use = function(self, direction)
		local entity = self.owner
		local target = hexagon.direction(entity.pos, direction)
		core.damage(entity, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
			type = "ground",
		})
		
		local splash = hexagon.range(target, 1)

		core.damage(entity, splash, {
			damage = entity.power / 10,
			element = "earth",
			accuracy = 1,
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

	modes = { "hammer", "shield" },

	update = function(self, tick)
		local entity = self.owner
		self.enable = not entity.status.final_guard

		if entity.status.shelter then
			self.cooldown = 1
		else
			self.cooldown = 0
		end
		return core.skill_update(self, tick)
	end,
	get = function(self)
		return self.owner.inventory[1].mode
	end,
	use = function(self, mode)
		local entity = self.owner

		if mode ~= "hammer" and mode ~= "shield" then
			return false
		end
		
		entity.inventory[1].mode = mode
		entity.status.shelter = nil
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
		local mode = entity.inventory[1].mode

		self.enable = (mode ~= "shield" and not entity.status.final_guard)

		return core.skill_update(self, tick)
	end,
	use = function(self, target)
		local entity = self.owner

		local dis = hexagon.distance(entity.pos, target, 2 * entity.map.scale)
		if  dis < self.range[1] or dis > self.range[2] then
			return false
		end
		
		core.damage(entity, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		})

		local splash = hexagon.range(target, 1)

		core.damage(entity, splash, {
			damage = entity.power / 10,
			element = "earth",
			accuracy = 1,
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
		local mode = entity.inventory[1].mode

		self.enable = (mode == "shield" and not entity.status.final_guard)

		return core.skill_update(self, tick)
	end,
	use = function(self, direction)
		local entity = self.owner
		
		local target = hexagon.fan(entity.pos, 2, direction + 5, direction + 7)
		core.damage(entity, target, {
			damage = entity.power / 5,
			element = "earth",
			accuracy = 1,
			type = "ground",
		})

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

	update = function(self, tick)
		local entity = self.owner
		local mode = entity.inventory[1].mode
		local active = entity.status.shelter

		self.enable = (mode == "shield" and not (entity.status.final_guard or active))
		
		return core.skill_update(self, tick)
	end,
	use = function(self)
		local entity = self.owner

		entity.status.shelter = true
		core.add_buff(entity, buff_shelter)

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

	update = function(self, tick)
		local entity = self.owner
		local active = entity.status.final_guard
		self.enable = not (active or entity.status.shelter)

		return core.skill_update(self, tick and not active)
	end,
	use = function(self)
		local entity = self.owner

		entity.status.final_guard = true
		core.add_buff(entity, buff_final_guard)

		return true
	end,
}

return function(team, pos)
	local shian = core.new_character("shian", team, pos, template, {
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
		mode = "hammer",
		tick = function(self)
		end,
		get = function(self)
			return self.name .. '\t' .. self.mode
		end,
	})

	shian.alive = function(self)
		return self.health > 0 or self.status.final_guard
	end
	return shian
end
