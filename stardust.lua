local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local function buff_ether_charge(charge)
	return {
		name = "ether_charge",

		initial = function(self)
			local entity = self.owner
			local p = buff.remove(entity, "ether_charge")
			if p then
				local val = p.charge + charge / 2
				core.damage(entity, {
					damage = val,
					element = "ether",
				})

				return false
			end

			self.charge = charge
			return charge > 0
		end,

		tick = {{
			core.priority.stat, function(self)
				if self.charge <= 100 then
					return false
				end

				self.charge = self.charge - 100
				return true
			end
		}}
	}
end

local template = {
	element = "ether",
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
		ether = -0.2,
		mental = 0.4,
	},
	quiver = {
		name = "ether",
		cost = 40,
		single = function(entity, target)
			entity.map:damage(entity.team, { target }, {
				damage = 100,
				element = "ether",
			}, buff.insert, buff_ether_charge, 0)
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "ether",
			}, buff.insert, buff_ether_charge, 200)
		end,

	},
}

local buff_ether_energy = {
	name = "ether_energy",
	tick = {{
		core.priority.pre_stat, function(self)
			local entity = self.owner
			if not entity.status.down then
				local val = entity.map:layer_get("ether", entity.pos)
				entity.generator = val
			end
			return true
		end
	}},
	defer = {
		core.priority.stat, function(self)
			local entity = self.owner
			if not entity.status.down then
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
			end
			entity.energy = 0
		end,
	}
}

local buff_hover = {
	name = "hover",
	cost = 40,
	power = 80,
	tick = {{
		core.priority.fly, function(self)
			local entity = self.owner
			if entity.status.down or entity.generator < self.cost then
				entity.hover = false
			end

			if entity.power < self.power then
				entity.hover = false
			end

			if entity.hover then
				entity.generator = entity.generator - self.cost
				entity.status.fly = true
			end

			return true
		end,
	}}
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,
	step = 1,
	power_req = 80,

	update = function(self)
		local entity = self.owner
		if entity.hover then
			self.cost = 10
			self.step = 3
		else
			self.cost = 0
			self.step = 1
		end

		self.enable = core.skill_update(self) and not entity.moved
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
	power_req = 80,

	update = function(self)
		local entity = self.owner
		local has_lance = false
		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				has_lance = true
			end
		end
		self.enable = core.skill_update(self) and has_lance
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
		}, buff.insert, buff_ether_charge, entity.power)

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
	power_req = 40,

	update = function(self)
		local entity = self.owner
		if entity.hover then
			self.cost = 0
		else
			self.cost = 40
		end
		self.enable = core.skill_update(self) and not entity.moved
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
	power_req = 20,

	update = function(self)
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

		self.enable = core.skill_update(self) and active
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
	power_req = 20,

	update = function(self)
		local entity = self.owner
		local mirror = entity.inventory[3]

		self.enable = core.skill_update(self) and (mirror.energy == mirror.energy_cap)
	end,
	use = function(self, target)
		local entity = self.owner
		local mirror = entity.inventory[3]
		if not hexagon.distance(entity.pos, target, self.range) then
			return false
		end

		local area = hexagon.range(target, 1)
		entity.map:layer_set("ether", "blackhole", entity.team, area, blackhole_duration, entity.power)

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
	power_req = 100,

	update = function(self)
		local entity = self.owner
		local prism = entity.inventory[4]

		self.enable = core.skill_update(self) and (prism.energy >= prism.energy_cap // 2)
	end,
	use = function(self, direction)
		local entity = self.owner
		local prism = entity.inventory[4]

		local area = hexagon.fan(entity.pos, 2 * (entity.map.scale + 1), direction, direction)
		entity.map:damage(entity.team, area, {
			damage = prism.energy / 2,
			element = "ether",
		}, buff.insert, buff_ether_charge, prism.energy / 4)

		prism.energy = 0
		return true
	end,
}

local skill_starfall = {
	name = "starfall",
	type = "target",
	cooldown = 20,
	remain = 0,
	enable = true,
	cost = 0,
	power_req = 80,

	update = function(self)
		local entity = self.owner
		local has_lance = false
		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				has_lance = true
			end
		end
		self.enable = core.skill_update(self) and has_lance

	end,
	use = function(self, target)
		local entity = self.owner

		buff(entity, {
			name = "starfall",
			target = target,
			defer = {
				core.priority.last, function(self)
					local entity = self.owner
					entity.map:layer_set("ether", "detonate", self.target, entity.power * 4)
				end,
			}
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

	buff.insert_notick(stardust, buff_ether_energy)
	buff.insert_notick(stardust, buff_hover)

	return stardust
end
