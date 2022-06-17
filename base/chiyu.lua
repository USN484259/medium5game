local cfg = require("base/config").entity.chiyu
local util = require("core/util")
local hexagon = require("core/hexagon")
local core = require("core/core")
local buff = require("core/buff")

local quiver = {
	name = "quiver.fire",
	element = "fire",
	cost = cfg.quiver.single.cost,
	range = cfg.quiver.single.range,
	shots = cfg.quiver.single.shots,
	single = function(entity, target)
		local t = cfg.quiver.single
		entity.map:damage(entity, target, t.damage, buff.insert, "burn", t.burn.damage, t.burn.duration)
	end,

	area = function(entity, area)
		local t = cfg.quiver.area
		entity.map:damage(entity, area, t.damage)

		entity.map:layer_set("fire", entity.team, area, t.set_fire.duration, t.set_fire.damage)
	end,
}

local buff_curse = {
	name = "buff.chiyu.curse_of_phoenix",
	tick = {{
		core.priority.post_stat, function(self)
			local entity = self.owner
			local t = cfg.item.ember
			local heat = math.max(0, math.floor(entity.inventory[1].heat - t.dissipate(entity.map:layer_get("air", entity.pos), entity.status.wet, entity.status.down)))

			entity.power = math.floor(t.power(entity.power, heat, entity.status.wet))
			entity.inventory[1].heat = heat

			return true
		end
	}, {
		core.priority.damage, function(self)
			local entity = self.owner
			local mental, fire = cfg.item.ember.damage(entity.inventory[1].heat)
			if mental then
				core.damage(entity, {
					damage = mental,
					element = "mental",
					real = true,
				})
			end
			if fire then
				core.damage(entity, {
					damage = fire,
					element = "fire",
					real = true,
				})
			end

			return true
		end
	}}
}

local function ember_damage(entity, ...)
	local count, killed = entity.map:damage(entity, ...)
	local t = cfg.item.ember
	for k, v in pairs(killed) do
		local val = math.min(v * t.regenerate.cap, entity.health_cap * t.regenerate.ratio)
		core.heal(entity, val)
	end
	local ember = entity.inventory[1]
	ember.heat = ember.heat + count * t.heat_gain.damage + #killed * t.heat_gain.kill
	return count
end

local skill_move = util.merge_table({
	name = "skill.chiyu.move",
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
	name = "skill.chiyu.attack",
	type = "direction",
	remain = 0,

	update = core.skill_update,
	use = function(self, direction)
		local entity = self.owner

		local target = hexagon.direction(entity.pos, direction)
		ember_damage(entity, { target }, self.damage, buff.insert, "burn", self.burn.damage, self.burn.duration)

		return true
	end,
}, cfg.skill.attack)

local skill_charge = util.merge_table({
	name = "skill.chiyu.charge",
	type = "vector",
	remain = 0,

	update = core.skill_update,
	use = function(self, direction, distance)
		local entity = self.owner

		if distance < self.range[1] or distance > self.range[2] then
			return false
		end

		local line = hexagon.line(entity.pos, direction, distance)

		local res = core.teleport(entity, line[#line])
		if res then
			ember_damage(entity, line, self.damage, buff.insert, "burn", self.burn.damage, self.burn.duration)

			ember_damage(entity, { line[#line - 1] }, self.back, buff.insert, "down", self.back.down_duration)
		end

		return res
	end,
}, cfg.skill.charge)

local skill_ignition = util.merge_table({
	name = "skill.chiyu.ignition",
	type = "target",
	remain = 0,

	update = function(self)
		local entity = self.owner
		self.enable = core.skill_update(self) and (entity.inventory[2].remain == 0)
	end,
	use = function(self, target)
		local entity = self.owner

		local dis = hexagon.distance(entity.pos, target, self.range[2])
		if not dis or dis < self.range[1]  then
			return false
		end

		local seed = {
			name = "seed.feather",
			element = "fire",
			team = entity.team,
			power = self.damage or (entity.power * self.damage_ratio),
			pos = target,
			radius = self.radius,
		}

		seed = entity.map:contact(seed)
		if seed then
			local area = hexagon.range(seed.pos, seed.radius)
			entity.map:damage(entity, area, {
				damage = seed.power,
				element = "fire",
			}, buff.insert, "burn", self.burn.damage, self.burn.duration)
			entity.map:layer_set("fire", entity.team, area, self.set_fire.duration, self.set_fire.damage)
		end

		local feather = entity.inventory[2]
		feather.remain = feather.cooldown

		return true
	end,
}, cfg.skill.ignition)

local skill_sweep = util.merge_table({
	name = "skill.chiyu.sweep",
	type = "direction",
	remain = 0,

	update = core.skill_update,
	use = function(self, direction)
		local entity = self.owner

		local area = hexagon.fan(entity.pos, self.damage.extent, direction + 6 - self.damage.angle, direction + 6 + self.damage.angle)
		ember_damage(entity, area, self.damage)

		local area = hexagon.fan(entity.pos, self.flame.extent, direction + 6 - self.flame.angle, direction + 6 + self.flame.angle)
		ember_damage(entity, area, self.flame, buff.insert, "burn", self.burn.damage, self.burn.duration)

		return true
	end,
}, cfg.skill.sweep)

local skill_nirvana = util.merge_table({
	name = "skill.chiyu.nirvana",
	type = "target",
	remain = 0,

	update = function(self)
		local entity = self.owner
		self.enable = core.skill_update(self) and (entity.health / entity.health_cap < self.threshold)
	end,
	use = function(self, target)
		local entity = self.owner
		local area = hexagon.range(entity.pos, self.set_fire.radius)

		local res = core.teleport(entity, target)
		if res then
			entity.map:layer_set("fire", entity.team, area, self.set_fire.duration, self.set_fire.damage)
		end

		return res
	end,
}, cfg.skill.nirvana)

local skill_phoenix = util.merge_table({
	name = "skill.chiyu.phoenix",
	type = "vector",
	remain = 0,

	update = function(self)
		local entity = self.owner
		self.enable = core.skill_update(self) and (entity.inventory[2].remain == 0)
	end,
	use = function(self, direction, distance)
		local entity = self.owner

		if distance <= 0 then
			return false
		end

		local main = hexagon.line(entity.pos, direction, distance)
		local sides = util.append_table(
			hexagon.line(hexagon.direction(entity.pos, direction + 5), direction, distance),
			hexagon.line(hexagon.direction(entity.pos, direction + 7), direction, distance))
		table.insert(sides, hexagon.direction(main[#main], direction))

		local res = core.teleport(entity, main[#main])
		if res then
			ember_damage(entity, main, self.main.damage, buff.insert, "burn", self.main.burn.damage, self.main.burn.duration)

			ember_damage(entity, sides, self.sides.damage, buff.insert, "burn", self.sides.burn.damage, self.sides.burn.duration)

			ember_damage(entity, { main[#main - 1] }, self.back.damage)

			ember_damage(entity, { main[#main - 1] }, self.back.extra, buff.insert, "down", self.back.down_duration)

			local area = util.append_table(main, sides)
			entity.map:layer_set("fire", entity.team, area, self.set_fire.duration, self.set_fire.damage)

			local feather = entity.inventory[2]
			feather.remain = feather.cooldown
		end

		return res
	end,
}, cfg.skill.phoenix)

return function(override)
	local chiyu = core.new_character("entity.chiyu", cfg.template, {
		skill_move,
		skill_attack,
		skill_charge,
		skill_ignition,
		skill_sweep,
		skill_nirvana,
		skill_phoenix,
	}, override)
	chiyu.quiver = quiver

	table.insert(chiyu.inventory, {
		name = "item.chiyu.ember",
		heat = cfg.item.ember.initial or 0,
		tick = function(self)
		end,
	})
	table.insert(chiyu.inventory, {
		name = "item.chiyu.feather",
		cooldown = cfg.item.feather.cooldown,
		remain = cfg.item.feather.initial,
		tick = core.common_tick,
	})

	buff.insert_notick(chiyu, buff_curse)

	return chiyu
end
