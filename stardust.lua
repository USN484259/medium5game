local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local buff_discharge = {
	name = "discharge",
	priority = core.priority.stat,
	unique = true,
	tick = function(self)
		local entity = self.owner
		if (entity.stars_charge or 0) <= 100 then
			entity.stars_charge = nil
			return false
		else
			entity.stars_charge = entity.stars_charge - 100
			return true
		end
	end
}

local function overcharge(entity, charge)
	if entity.stars_charge then
		local val = entity.stars_charge + charge / 2
		entity.stars_charge = 0
		core.damage(entity, {
			damage = val,
			element = "star",
		})
	elseif charge > 0 then
		entity.stars_charge = charge
		buff(entity, buff_discharge)
	end
end

local template = {
	health_cap = 800,
	speed = 6,
	accuracy = 8,
	power = 200,
	sight = 3,
	energy_cap = 65535,
	generator = 0,
	moved = false,

	resistance = {
		physical = 0.2,
		fire = 0.2,
		water = 0.2,
		air = 0.2,
		earth = 0.2,
		star = -0.2,
		mental = 0.4,
	},
	quiver = {
		name = "star",
		cost = 40,
		single = function(entity, target)
			entity.map:damage(entity.team, { target }, {
				damage = 100,
				element = "star",
			}, overcharge, 0)
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "star",
			}, overcharge, 200)
		end,

	},
}

local buff_star_energy = {
	name = "star_energy",
	priority = core.priority.stat,
	tick = function(self)
		local entity = self.owner
		local val = entity.map:get(entity.pos, "star_energy")
		entity.generator = val

		return true
	end,
	defer = function(self)
		local entity = self.owner
		local energy = entity.energy

		for i = 1, #entity.inventory, 1 do
			local item = entity.inventory[i]
			if not item.active then
				local need = item.energy_cap - item.energy
				if energy > need then
					energy = energy - need
					item.energy = item.energy_cap
				else
					item.energy = item.energy + energy
					energy = 0
					break
				end
			end
		end
--[[
		while energy > 0 do
			local count = 0
			local min_need = energy
			for i = 1, #entity.inventory, 1 do
				local item = entity.inventory[i]
				local need = item.energy_cap - item.energy
				if need > 0 and not item.active then
					count = count + 1
					min_need = math.min(need, min_need)
				end
			end
			if count == 0 then
				break
			end

			min_need = math.min(min_need, math.ceil(energy / count))

			for i = 1, #entity.inventory, 1 do
				local item = entity.inventory[i]
				if item.energy < item.energy_cap and not item.active then
					local val = math.min(energy, min_need, item.energy_cap - item.energy)
					item.energy = item.energy + val
					energy = energy - val
				end
			end
		end
--]]
		entity.energy = 0
	end,
}

local buff_hover = {
	name = "hover",
	priority = core.priority.post_stat,
	cost = 40,
	tick = function(self)
		local entity = self.owner
		if entity.generator < self.cost then
			entity.hover = false
		end

		if entity.hover then
			entity.generator = entity.generator - self.cost
			entity.status.fly = true
		end

		return true
	end,
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,
	step = 1,

	update = function(self, tick)
		local entity = self.owner
		if entity.hover then
			self.cost = 10
			self.step = 3
		else
			self.cost = 0
			self.step = 1
		end

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
	type = "target",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,
	range = 5,

	update = function(self, tick)
		local entity = self.owner
		local has_lance = false
		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				has_lance = true
			end
		end
		self.enable = core.skill_update(self, tick) and has_lance
	end,
	use = function(self, target)
		local entity = self.owner

		if not hexagon.distance(entity.pos, target, self.range) then
			return false
		end
		entity.map:damage(entity.team, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		}, overcharge, entity.power)

		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				item.energy = 0
				break
			end
		end

		return true
	end,
}

local skill_hover = {
	name = "hover",
	type = "toggle",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 40,

	update = function(self, tick)
		local entity = self.owner
		if entity.hover then
			self.cost = 0
		else
			self.cost = 40
		end
		self.enable = core.skill_update(self, tick) and not entity.moved
	end,
	use = function(self)
		local entity = self.owner
		if entity.hover then
			entity.hover = false
			entity.status.fly = nil
		else
			entity.hover = true
			entity.status.fly = true
		end

		return true
	end,
}

local skill_teleport = {
	name = "teleport",
	type = "target",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 0,

	update = function(self, tick)
		local entity = self.owner
		local mirror = entity.inventory[3]
		local active = false

		if mirror.portal then
			self.type = "effect"
			active = not entity.moved
		else
			self.type = "target"
			active = (mirror.energy == mirror.energy_cap)
		end

		self.enable = core.skill_update(self, tick) and active
	end,
	use = function(self, target)
		local entity = self.owner
		local mirror = entity.inventory[3]

		if mirror.portal then
			local e = entity.map:get(mirror.portal)
			if e and e.team == entity.team then
				e.pos, entity.pos = entity.pos, e.pos
			elseif not core.teleport(entity, mirror.portal) then
				return false
			end
			mirror.portal = nil

			return true
		end

		if hexagon.distance(entity.pos, target, 1) then
			return false
		end

		local orig_pos = entity.pos
		if not core.teleport(entity, target) then
			return false
		end

		if entity.hover then
			mirror.energy = mirror.energy_cap // 2
			mirror.portal = orig_pos
			mirror.active = 1
		else
			for d = 1, 6, 1 do
				local p = hexagon.direction(orig_pos, d)
				local e = entity.map:get(p)
				if e and e.team == entity.team and not e.status.ultimate then
					local t = hexagon.direction(entity.pos, d)
					core.teleport(e, t)
				end
			end

			mirror.energy = 0
		end

		return true
	end,
}

local blackhole_duration = 2

local skill_blackhole = {
	name = "blackhole",
	type = "target",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 0,
	range = 6,
	-- duration = 2,

	update = function(self, tick)
		local entity = self.owner
		local mirror = entity.inventory[3]

		self.enable = core.skill_update(self, tick) and (mirror.energy == mirror.energy_cap)
	end,
	use = function(self, target)
		local entity = self.owner
		local mirror = entity.inventory[3]
		if not hexagon.distance(entity.pos, target, self.range) then
			return false
		end
		
		local area = hexagon.range(target, 1)
		entity.map:effect(entity.team, area, "blackhole", blackhole_duration, 4)

		mirror.energy = mirror.energy_cap // 4
		mirror.active = blackhole_duration

		return true
	end,
}

local skill_lazer = {
	name = "lazer",
	type = "directtion",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 0,

	update = function(self, tick)
		local entity = self.owner
		local prism = entity.inventory[4]

		self.enable = core.skill_update(self, tick) and (prism.energy >= prism.energy_cap // 2)
	end,
	use = function(self, direction)
		local entity = self.owner
		local prism = entity.inventory[4]

		local area = hexagon.fan(entity.pos, 2 * (entity.map.scale + 1), direction, direction)
		entity.map:damage(entity.team, area, {
			damage = prism.energy / 2,
			element = "star",
		}, overcharge, prism.energy / 4)

		prism.energy = 0
		return true
	end,
}

local skill_starfall = {
	name = "starfall",
	type = "target",
	cooldown = 40,
	remain = 0,
	enable = true,
	cost = 0,

	update = function(self, tick)
		local entity = self.owner
		local has_lance = false
		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				has_lance = true
			end
		end
		self.enable = core.skill_update(self, tick) and has_lance

	end,
	use = function(self, target)
		local entity = self.owner

		buff(entity, {
			name = "starfall",
			priority = core.priority.last,
			target = target,
			tick = function(self)
				return false
			end,
			defer = function(self)
				local entity = self.owner
				local val = entity.map:get(self.target, "star_energy")
				local area = hexagon.range(self.target, 2)
				entity.map:damage(0, area, {
					damage = 16 * val,
					element = "star",
				}, overcharge, 8 * val)
			end,
		})


		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				item.energy = 0
				break
			end
		end

		self.energy = 0
		entity.hover = false
		entity.status.fly = nil
		entity.status.down = true
		buff(entity, "down", 1)
		return true

	end,
}

return function()
	local stardust = core.new_character("stardust", template, {
		skill_move,
		skill_attack,
		skill_hover,
		skill_teleport,
		skill_blackhole,
		skill_lazer,
		skill_starfall,
	})

	stardust.hover = false

	for i = 1, 2, 1 do
		table.insert(stardust.inventory, {
			name = "stars_lance",
			energy_cap = 200,
			energy = 200,
			tick = function(self)
			end,
		})
	end

	table.insert(stardust.inventory, {
		name = "stars_mirror",
		energy_cap = 600,
		energy = 0,
		tick = function(self)
			if self.active and self.active > 0 then
				self.active = self.active - 1
			else
				self.active = nil
				self.portal = nil
			end
		end,
	})

	table.insert(stardust.inventory, {
		name = "stars_prism",
		energy_cap = 2000,
		energy = 0,
		tick = function(self)
		end,
	})

	buff(stardust, buff_star_energy)
	buff(stardust, buff_hover)

	return stardust
end
