local cfg = require("base/config").entity.shian
local util = require("core/util")
local hexagon = require("core/hexagon")
local core = require("core/core")
local buff = require("core/buff")


local quiver = {
	name = "quiver.earth",
	element = "earth",
	cost = cfg.quiver.single.cost,
	range = cfg.quiver.single.range,
	shots = cfg.quiver.single.shots,
	single = function(entity, target)
		entity.map:damage(entity, target, cfg.quiver.single.damage)
	end,

	area = function(entity, area)
		entity.map:damage(entity, area, cfg.quiver.area.damage)
	end,
}



local buff_apple = {
	name = "buff.shian.apple",
	priority = core.priority.stat,
	duration = cfg.item.apple.duration,
	tick = {{
		core.priority.pre_stat, function(self)
			local entity = self.owner
			local t = cfg.item.apple

			if self.duration >= (t.duration - t.boost_duration) then
				entity.generator = entity.generator * t.generator_boost
				entity.power = entity.power * t.power_boost
				entity.speed = entity.speed + t.speed_boost or 0
				entity.accuracy = entity.accuracy + t.accuracy_boost or 0
			end
			return true
		end
	}, {
		core.priority.damage, function(self)
			local entity = self.owner
			core.damage(entity, cfg.item.apple.damage)
			return true
		end
	}}
}

local buff_shield = {
	name = "buff.shian.shield",
	tick = {{
		core.priority.stat, function(self)
			local entity = self.owner
			if entity.inventory[1]:get() == "shield" and not entity.status.ultimate then
				entity.speed = math.floor(entity.speed * cfg.item.shield.speed_ratio)
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
			local t = cfg.item.shield
			local list = entity.map:get_area(hexagon.range(entity.pos, t.radius))
			for k, e in pairs(list) do
				if e.team == entity.team and e.type == "character" then
					core.hook(e, {
						name = "hook.shian.shield",
						priority = core.priority.shield,
						origin = entity,
						func = function(self, entity, damage)
							local origin = self.origin
							local blk
							-- absorb <efficiency> damage using 1 energy
							blk, damage = core.shield(damage, t.energy_efficiency * origin.energy, t.absorb_efficiency)
							origin.map:event(entity, "shield", origin.inventory[1], blk)
							origin.energy = math.floor(origin.energy - blk / t.energy_efficiency)
							return damage
						end
					})
				end
			end
		end,
	}
}

local buff_final_guard = {
	name = "buff.shian.final_guard",
	duration = cfg.skill.final_guard.duration,

	tick = {{
		core.priority.ultimate, function(self)
			local entity = self.owner
			local t = cfg.skill.final_guard

			entity.status.ultimate = true
			entity.generator = 0
			entity.speed = 0
			for k, v in pairs(entity.resistance) do
				entity.resistance[k] = math.min(v, t.max_resistance)
			end

			local list = entity.map:get_team(entity.team)
			for k, e in pairs(list) do
				if e.type == "character" then
					core.hook(e, {
						name = "hook.shian.final_guard",
						priority = core.priority.shield,
						origin = entity,
						func = function(self, entity, damage)
							local origin = self.origin
							local blk
							-- absorb <efficiency> damage using 1 energy
							blk, damage = core.shield(damage, t.energy_efficiency * origin.energy)
							origin.map:event(entity, "shield", origin, blk)
							origin.energy = origin.energy - blk // t.energy_efficiency

							if damage then
								-- absorb <efficiency> damage using 1 health
								core.damage(origin, {
									damage = damage.damage / t.blood_efficiency,
									element = damage.element,
									real = true,
								})
							end
							return nil
						end
					})
				end
			end

			return true
		end,
	}}
}

local skill_move = {
	name = "skill.shian.move",
	type = "waypoint",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local mode = entity.inventory[1]:get()

		util.merge_table(self, cfg.skill.move[mode])

		self.enable = core.skill_update(self) and not entity.moved
	end,
	use = function(self, ...)
		local entity = self.owner
		local waypoint = table.pack(...)
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
	name = "skill.shian.attack",
	type = "direction",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local mode = entity.inventory[1]:get()
		local t = cfg.skill.attack[mode]

		self.cooldown = t.cooldown
		self.cost = t.cost
		self.power_req = t.power_req

		if mode == "hammer" then
			self.name = "skill.shian.smash"
			self.use = function(self, direction)
				local entity = self.owner
				local target = hexagon.direction(entity.pos, direction)
				entity.map:damage(entity, { target }, t.damage, buff.insert, "down", t.damage.down_duration)

				local splash = hexagon.range(target, t.splash.radius)

				entity.map:damage(entity, splash, t.splash)

				return true
			end
		elseif mode == "shield" then
			self.name = "skill.shian.spike"
			self.use = function(self, direction)
				local entity = self.owner
				local target = hexagon.fan(entity.pos, t.extent, direction + 6 - t.angle, direction + 6 + t.angle)
				entity.map:damage(entity, target, t.damage, buff.insert, "block", entity.power * t.block.ratio, t.block.duration)

				return true
			end
		end

		core.skill_update(self)
	end,
}

local skill_transform = util.merge_table({
	name = "skill.shian.transform",
	type = "toggle",
	remain = 0,
	item = "item.shian.yankai",

	update = core.skill_update,
	use = function(self)
		local entity = self.owner
		entity.inventory[1]:next()
		return true
	end,
}, cfg.skill.transform)

local skill_cannon = util.merge_table({
	name = "skill.shian.cannon",
	type = "target",
	remain = 0,

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

		local res = entity.map:damage(entity, { target }, self.damage, buff.insert, "down", self.damage.down_duration)
		if res > 0 then
			-- extra damage to flying target
			entity.map:damage(entity, { target }, self.air_extra)
		end

		local area = hexagon.range(target, self.splash.radius)
		entity.map:damage(entity, area, self.splash)

		return true
	end,
}, cfg.skill.cannon)

local skill_apple = util.merge_table({
	name = "skill.shian.apple",
	type = "effect",
	remain = 0,

	update = function(self)
		local entity = self.owner
		self.enable = core.skill_update(self) and (entity.inventory[2].remain == 0)
	end,
	use = function(self)
		local entity = self.owner

		core.generate(entity, self.instant.generate)

		core.damage(entity, self.instant.damage)
		buff.insert(entity, buff_apple)
		local apple = entity.inventory[2]
		apple.remain = apple.cooldown

		return true
	end,
}, cfg.skill.apple)

local skill_final_guard = util.merge_table({
	name = "skill.shian.final_guard",
	type = "effect",
	remain = 0,

	update = core.skill_update,
	use = function(self)
		local entity = self.owner

		buff.insert(entity, buff_final_guard)

		return true
	end,
}, cfg.skill.final_guard)

return function(override)
	local shian = core.new_character("entity.shian", cfg.template, {
		skill_move,
		skill_attack,
		skill_transform,
		skill_cannon,
		skill_apple,
		skill_final_guard,
	}, override)
	shian.quiver = quiver

	table.insert(shian.inventory, {
		name = "item.shian.yankai",
		modes = cfg.item.shield.modes,
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
		name = "item.shian.apple",
		cooldown = cfg.item.apple.cooldown,
		remain = cfg.item.apple.initial,
		tick = core.common_tick,
	})


	shian.alive = function(self)
		return self.health > 0 or self.status.ultimate
	end

	buff.insert_notick(shian, buff_shield)

	return shian
end
