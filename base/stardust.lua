local cfg = require("base/config").entity.stardust
local util = require("core/util")
local hexagon = require("core/hexagon")
local core = require("core/core")
local buff = require("core/buff")

local function buff_charge(charge)
	return {
		name = "buff.stardust.charge",

		initial = function(self)
			local entity = self.owner
			local p = buff.remove(entity, self.name)
			if p then
				local val = cfg.charge.damage(p.charge, charge)
				core.damage(entity, {
					damage = val,
					element = "light",
				})

				return false
			end

			self.charge = charge
			return charge > 0
		end,

		tick = {{
			core.priority.stat, function(self)
				if self.charge <= cfg.charge.dissipate then
					return false
				end

				self.charge = self.charge - cfg.charge.dissipate
				return true
			end
		}}
	}
end

local quiver = {
	name = "quiver.light",
	element = "light",
	cost = cfg.quiver.single.cost,
	range = cfg.quiver.single.range,
	shots = cfg.quiver.single.shots,
	single = function(entity, target)
		entity.map:damage(entity, target, cfg.quiver.single.damage, buff.insert_notick, buff_charge, cfg.quiver.single.charge)
	end,

	area = function(entity, area)
		entity.map:damage(entity, area, cfg.quiver.area.damage, buff.insert_notick, buff_charge, cfg.quiver.area.charge)
	end,

}

local buff_generator = {
	name = "buff.stardust.generator",
	tick = {{
		core.priority.first, function(self)
			local entity = self.owner
			if not entity.status.down then
				local src = entity.map:layer_get("light", entity.pos, "source")
				local val = 0
				for k, v in pairs(src) do
					local dis = hexagon.distance(v.pos, entity.pos, cfg.generator.range)
					if dis then
						val = val + v.energy / (dis + 1) ^ cfg.generator.exp
					end
				end
				entity.generator = math.floor(val)
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
	name = "buff.stardust.hover",
	cost = cfg.skill.hover.cost,
	power = cfg.template.power * cfg.skill.hover.power_req,
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
				entity.speed = entity.speed + cfg.skill.hover.speed_boost
			end

			return true
		end,
	}}
}

local skill_move = {
	name = "skill.stardust.move",
	type = "waypoint",
	remain = 0,

	update = function(self)
		local entity = self.owner
		if entity.hover then
			util.merge_table(self, cfg.skill.move.hover)
		else
			util.merge_table(self, cfg.skill.move.ground)
		end

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

local skill_attack = util.merge_table({
	name = "skill.stardust.attack",
	type = "target",
	remain = 0,

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
		entity.map:damage(entity, { target }, self.damage, buff.insert_notick, buff_charge, entity.power * self.damage.ratio * self.charge_rate)

		for i = 1, 2, 1 do
			local item = entity.inventory[i]
			if item.energy == item.energy_cap then
				item.energy = 0
				break
			end
		end

		return true
	end,
}, cfg.skill.attack)

local skill_hover = util.merge_table({
	name = "skill.stardust.hover",
	type = "toggle",
	remain = 0,

	update = function(self)
		local entity = self.owner
		if entity.hover then
			self.cost = 0
		else
			self.cost = cfg.skill.hover.cost
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
}, cfg.skill.hover)

local skill_teleport = util.merge_table({
	name = "skill.stardust.teleport",
	remain = 0,

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
			mirror.active = nil
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
			mirror.energy = mirror.energy_cap * (1 - self.energy_cost.solo)
			mirror.portal = orig_pos
			mirror.active = self.portal_duration
		else
			for d = 1, 6, 1 do
				local p = hexagon.direction(orig_pos, d)
				local e = entity.map:get(p)
				if e and e.team == entity.team and (e.free_ultimate or not e.status.ultimate) then
					local t = hexagon.direction(entity.pos, d)
					core.teleport(e, t)
				end
			end

			mirror.energy = mirror.energy_cap * (1 - self.energy_cost.group)
		end

		return true
	end,
}, cfg.skill.teleport)


local skill_blackhole = util.merge_table({
	name = "skill.stardust.blackhole",
	type = "target",
	remain = 0,

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

		local info = {
			team = entity.team,
			pos = target,
			radius = self.radius,
			duration = self.duraion,
			power = entity.power * self.power_ratio,
			crush_threshold = self.crush_threshold,
		}
		entity.map:layer_set("light", "blackhole", info)

		mirror.energy = mirror.energy_cap * (1 - self.energy_cost)
		mirror.active = self.duration

		return true
	end,
}, cfg.skill.blackhole)

local skill_lazer = util.merge_table({
	name = "skill.stardust.lazer",
	type = "direction",
	remain = 0,

	update = function(self)
		local entity = self.owner
		local prism = entity.inventory[4]

		self.enable = core.skill_update(self) and (prism.energy >= prism.energy_cap * self.threshold)
	end,
	use = function(self, direction)
		local entity = self.owner
		local prism = entity.inventory[4]

		local area = hexagon.line(entity.pos, direction, 2 * (entity.map.scale + 1))
		local d = prism.energy * self.efficiency
		entity.map:damage(entity, area, {
			damage = d,
			element = "light",
		}, buff.insert_notick, buff_charge, d * self.charge_rate)

		prism.energy = 0
		return true
	end,
}, cfg.skill.lazer)

local skill_starfall = util.merge_table({
	name = "skill.stardust.starfall",
	type = "target",
	remain = 0,

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

		buff.insert(entity, {
			name = "buff.stardust.starfall",
			target = target,
			power = entity.power,
			duration = 0,
			detonate_cfg = {
				damage = self.damage,
				trigger_radius = self.trigger_radius,
			},
			defer = {
				core.priority.last, function(self)
					local entity = self.owner
					entity.map:layer_set("light", "detonate", self.target, self.detonate_cfg, self.power)
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
		buff.insert(entity, "down", self.down_duration)
		return true

	end,
}, cfg.skill.starfall)

return function(override)
	local stardust = core.new_character("entity.stardust", cfg.template, {
		skill_move,
		skill_attack,
		skill_hover,
		skill_teleport,
		skill_blackhole,
		skill_lazer,
		skill_starfall,
	}, override)
	stardust.quiver = quiver

	stardust.hover = false

	for i = 1, 2, 1 do
		table.insert(stardust.inventory, {
			name = "item.stardust.lance",
			energy_cap = cfg.item.lance.energy_cap,
			energy = cfg.item.lance.initial,
			tick = function(self)
			end,
		})
	end

	table.insert(stardust.inventory, {
		name = "item.stardust.mirror",
		energy_cap = cfg.item.mirror.energy_cap,
		energy = cfg.item.mirror.initial,
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
		name = "item.stardust.prism",
		energy_cap = cfg.item.prism.energy_cap,
		energy = cfg.item.prism.initial,
		tick = function(self)
		end,
	})

	buff.insert_notick(stardust, buff_generator)
	buff.insert_notick(stardust, buff_hover)

	return stardust
end
