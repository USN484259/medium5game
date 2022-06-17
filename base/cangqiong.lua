local cfg = require("base/config").entity.cangqiong
local util = require("core/util")
local hexagon = require("core/hexagon")
local core = require("core/core")
local buff = require("core/buff")

local quiver = {
	name = "quiver.air",
	element = "air",
	cost = cfg.quiver.single.cost,
	range = cfg.quiver.single.range,
	shots = cfg.quiver.single.shots,
	area = function(entity, area)
		entity.map:damage(entity, area, cfg.quiver.area.damage)
	end,
}


local buff_storm = {
	name = "buff.cangqiong.storm",
	priority = core.priority.ultimate,
	duration = cfg.skill.storm.duration,

	tick = {{
		core.priority.ultimate, function(self)
			local entity = self.owner
			entity.status.ultimate = true
			entity.speed = math.floor(entity.speed * cfg.skill.storm.speed_ratio)
			buff.remove(entity, "storm")
			return true
		end
	}}
}

local skill_move = util.merge_table({
	name = "skill.cangqiong.move",
	type = "waypoint",
	remain = 0,

	update = function(self)
		local entity = self.owner
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
}, cfg.skill.move)

local skill_attack = util.merge_table({
	name = "skill.cangqiong.attack",
	type = "multitarget",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local arrow = entity.inventory[1]:get()

		self.shots = arrow.shots or 1
		self.cost = cfg.skill.attack.cost + (arrow.cost or 0)
		self.range = arrow.range
		self.attach = arrow.single

		core.skill_update(self)
	end,
	use = function(self, target_list)
		local entity = self.owner

		if not core.multi_target(self, target_list) then
			return false
		end
		for k, v in pairs(target_list) do
			local res = entity.map:damage(entity, { v }, self.damage)
			if res > 0 and self.attach then
				self.attach(entity, { v })
			end
		end

		return true
	end,
}, cfg.skill.attack)

local skill_select_arrow = util.merge_table({
	name = "skill.cangqiong.select_arrow",
	type = "toggle",
	remain = 0,
	item = "item.cangqiong.lanyu",

	update = core.skill_update,
	use = function(self)
		local bow = self.owner.inventory[1]
		bow:next()
		return true
	end,
}, cfg.skill.select_arrow)

local skill_probe = util.merge_table({
	name = "skill.cangqiong.probe",
	type = "target",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local butterfly = entity.inventory[2]
		self.enable = core.skill_update(self) and butterfly.remain > 0
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
}, cfg.skill.probe)

local skill_wind_control = util.merge_table({
	name = "skill.cangqiong.wind_control",
	type = "line",
	remain = 0,

	update = core.skill_update,
	use = function(self, point, direction)
		local entity = self.owner

		if not hexagon.distance(entity.pos, point, self.range) then
			return false
		end

		local area = hexagon.line(point, direction, self.length - 1)
		entity.map:layer_set("air", "wind", area, direction, self.duration)
		return true
	end,
}, cfg.skill.wind_control)

local skill_arrow_rain = util.merge_table({
	name = "skill.cangqiong.arrow_rain",
	type = "effect",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local arrow = entity.inventory[1]:get()
		self.func = arrow.area

		core.skill_update(self)
	end,
	use = function(self)
		local entity = self.owner
		local bow = entity.inventory[1]

		self.func(entity, hexagon.range(entity.pos, self.radius))
		return true
	end,
}, cfg.skill.arrow_rain)

local skill_storm = util.merge_table({
	name = "skill.cangqiong.storm",
	type = "effect",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local butterfly = entity.inventory[2]

		self.enable = core.skill_update(self) and butterfly.remain == 0
	end,
	use = function(self)
		local entity = self.owner
		local butterfly = entity.inventory[2]

		local info = {
			team = entity.team,
			pos = entity.pos,
			radius = self.radius,
			duration = self.duration,
			power = entity.power * self.power_ratio,
		}

		entity.map:layer_set("air", "storm", info)

		butterfly.remain = butterfly.cooldown
		buff.insert(entity, buff_storm)

		return true
	end,
}, cfg.skill.storm)

return function(override)
	local cangqiong = core.new_character("entity.cangqiong", cfg.template, {
		skill_move,
		skill_attack,
		skill_select_arrow,
		skill_probe,
		skill_wind_control,
		skill_arrow_rain,
		skill_storm,
	}, override)
	cangqiong.quiver = quiver

	table.insert(cangqiong.inventory, {
		name = "item.cangqiong.lanyu",
		owner = cangqiong,
		modes = {},
		select = 1,

		tick = function(self)
			local entity = self.owner
			self.modes = {}
			local list = entity.map:get_area(hexagon.range(entity.pos, cfg.item.lanyu.reach))
			for k, e in pairs(list) do
				if e.team == entity.team and e.quiver then
					table.insert(self.modes, e.quiver)
				end
			end

			assert(#self.modes > 0)
			table.sort(self.modes, function(a, b)
				return a.element < b.element
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
		name = "item.cangqiong.butterfly",
		cooldown = cfg.item.butterfly.cooldown,
		remain = 0,
		tick = core.common_tick,
	})

	buff.insert_notick(cangqiong, "fly")

	return cangqiong
end
