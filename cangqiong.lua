local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local template = {
	health_cap = 1000,
	speed = 8,
	accuracy = 9,
	power = 100,
	sight = 4,
	energy_cap = 1000,
	generator = 100,
	moved = false,

	resistance = {
		physical = 0,
		fire = 0,
		water = 0,
		air = 0.2,
		earth = 0,
		star = 0,
		mental = 0,
	},

	quiver = {
		name = "air",

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "physical",
			})
		end,
	},

}

local storm_duration = 3

local buff_storm = {
	name = "storm",
	priority = core.priority.damage,
	duration = storm_duration,
	tick = function(self)
		local entity = self.owner
		if not core.common_tick(self) then
			return false
		end
		entity.map:damage(entity.team, hexagon.range(entity.pos, 4), {
			damage = 60,
			element = "air",
		})

		entity.status.ultimate = true
		return true
	end,
}

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 10,
	step = 3,

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
	type = "target",
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 40,

	update = function(self, tick)
		local entity = self.owner
		local arrow = entity.inventory[1]:get()

		self.cost = 40 + (arrow.cost or 0)
		self.range = arrow.range
		self.attach = arrow.single

		core.skill_update(self, tick)
	end,
	use = function(self, target)
		local entity = self.owner

		if self.range and not hexagon.distance(entity.pos, target, self.range) then
			return false
		end
		local res = entity.map:damage(entity.team, { target }, {
			damage = entity.power,
			element = "physical",
			accuracy = entity.accuracy,
		})
		if res > 0 and self.attach then
			self.attach(entity, target)
		end

		return true
	end,
}

local skill_select = {
	name = "select_arrow",
	type = "toggle",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 0,

	update = core.skill_update,
	use = function(self)
		local bow = self.owner.inventory[1]
		bow:next()
		return true
	end,
}

local skill_probe = {
	name = "probe",
	type = "target",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 80,
	noblock = true,

	update = function(self, tick)
		local entity = self.owner
		local butterfly = entity.inventory[2]
		self.enable = core.skill_update(self, tick) and butterfly.remain > 0
	end,
	use = function(self, target)
		local entity = self.owner
		local butterfly = entity.inventory[2]

		print("FIXME: cangqiong:probe not implemented")
		return false
--[[
		butterfly.remain = butterfly.cooldown
		return true
--]]
	end,
}

local skill_wind_control = {
	name = "wind_control",
	type = "vector",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 80,
	noblock = true,
	range = 4,
	length = 3,

	update = core.skill_update,
	use = function(self, point, direction)
		local entity = self.owner

		if not hexagon.distance(entity.pos, point, self.range) then
			return false
		end

		local area = hexagon.fan(point, self.length - 1, direction, direction)
		entity.map:effect(entity.team, area, "wind", direction, 2)
		return true
	end,
}

local skill_arrow_rain = {
	name = "arrow_rain",
	type = "effect",
	cooldown = 6,
	remain = 0,
	enable = true,
	cost = 300,
	range = 3,

	update = function(self, tick)
		local entity = self.owner
		local arrow = entity.inventory[1]:get()
		self.func = arrow.area

		core.skill_update(self, tick)
	end,
	use = function(self)
		local entity = self.owner
		local bow = entity.inventory[1]

		self.func(entity, hexagon.range(entity.pos, self.range))
		return true
	end,
}

local skill_storm = {
	name = "storm",
	type = "effect",
	cooldown = 10,
	remain = 0,
	enable = true,
	cost = 800,
	range = 5,

	update = function(self, tick)
		local entity = self.owner
		local butterfly = entity.inventory[2]
		local active = entity.status.ultimate

		self.enable = core.skill_update(self, tick and not active) and butterfly.remain == 0
	end,
	use = function(self)
		local entity = self.owner
		local butterfly = entity.inventory[2]

		entity.map:effect(entity.team, hexagon.range(entity.pos, self.range), "storm", entity.pos, self.range, storm_duration)

		entity.status.ultimate = true
		butterfly.remain = butterfly.cooldown
		buff(entity, buff_storm)

		return true
	end,
}

return function()
	local cangqiong = core.new_character("cangqiong", template, {
		skill_move,
		skill_attack,
		skill_select,
		skill_probe,
		skill_wind_control,
		skill_arrow_rain,
		skill_storm,
	})

	table.insert(cangqiong.inventory, {
		name = "lanyu",
		owner = cangqiong,
		modes = {},
		select = 1,

		tick = function(self)
			local entity = self.owner
			self.modes = {}
			local list = entity.map:get_area(hexagon.range(entity.pos, 1))
			for k, e in pairs(list) do
				if e.team == entity.team and e.quiver then
					table.insert(self.modes, e.quiver)
				end
			end

			assert(#self.modes > 0)
			table.sort(self.modes, function(a, b)
				return a.name < b.name
			end)
			self.select = 1
		end,
		get = function(self)
			return self.modes[self.select]
		end,
		next = function(self)
			self.select = self.select % #self.modes + 1
		end,

	})

	table.insert(cangqiong.inventory, {
		name = "butterfly",
		cooldown = 6,
		remain = 0,
		tick = core.common_tick,
	})

	buff(cangqiong, "fly")

	return cangqiong
end
