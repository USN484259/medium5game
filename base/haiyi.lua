local cfg = require("config").entity
local cfg_bubble = cfg.bubble
cfg = cfg.haiyi

local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")


local function bubble_trigger(entity, buff_name, ...)
	if entity.name == "entity.bubble" then
		entity.map:kill(entity)
		return
	end
	local b = buff.remove(entity, "bubble")
	if b then
		core.damage(entity, {
			damage = b.strength * cfg_bubble.damage.ratio,
			element = cfg_bubble.damage.element,
		})
	end

	if buff_name then
		buff.insert(entity, buff_name, ...)
	end

end

local quiver = {
	name = "quiver.water",
	element = "water",
	cost = cfg.quiver.single.cost,
	range = cfg.quiver.single.range,
	shots = cfg.quiver.single.shots,
	single = function(entity, target)
		local t = cfg.quiver.single
		entity.map:damage(entity, target, t.damage, buff.insert, "bubble", entity.team, entity.power * t.bubble.ratio, t.bubble.duration)
	end,

	area = function(entity, area)
		local t = cfg.quiver.area
		entity.map:damage(entity, area, t.damage, buff.insert, "bubble", entity.team, entity.power * t.bubble.ratio, t.bubble.duration)

		entity.map:heal(entity, area, t.heal, buff.insert, "bubble", entity.team, entity.power * t.bubble.ratio, t.bubble.duration)
	end,
}


local function in_water(entity)
	local water = entity.map:layer_get("water", entity.pos)
	return water and water > 0
end

local function check_water(skill)
	local entity = skill.owner
	local req = skill.water_cost
	local stored_water = entity.inventory[2].water
	local ground_water = 0

	local area = hexagon.range(entity.pos, 1)
	for k, p in pairs(area) do
		ground_water = ground_water + (entity.map:layer_get("water", p) or 0)
	end
	return stored_water + ground_water >= req
end

local function consume_water(skill)
	local entity = skill.owner
	local req = skill.water_cost
	local ground_water = true

	while req > 0 do
		if not ground_water then
			local jellyfish = entity.inventory[2]
			jellyfish.water = math.max(0, jellyfish.water - req)
			break
		end

		ground_water = false
		local count = 0
		local ring = hexagon.adjacent(entity.pos)
		for k, p in pairs(ring) do
			local val = entity.map:layer_get("water", p)
			if val and val > 0 then
				count = count + 1
			end
		end

		local unit
		local val = entity.map:layer_get("water", entity.pos)
		if val and val > 0 then
			unit = math.ceil(req / (count + cfg.item.wand.center_weight))
			req = req - entity.map:layer_set("water", "depth", entity.pos, - math.min(req, cfg.item.wand.center_weight * unit))
			ground_water = true
		elseif count > 0 then
			unit = math.ceil(req / count)
		end

		-- print("comsume_water " .. req .. '\t' .. tostring(unit))

		if unit then
			for k, p in pairs(ring) do
				if req <= 0 then
					break
				end
				req = req - (entity.map:layer_set("water", "depth", p, -unit) or 0)
				ground_water = true
			end
		end
	end
end

local function water_area(entity, range, shore)
	threshold = threshold or 0
	return hexagon.connected(entity.pos, range, function(a, b)
		local w_a = entity.map:layer_get("water", a)
		if w_a and w_a > 0 then
			if shore then
				return true
			end

			local w_b = entity.map:layer_get("water", b)
			return w_b and w_b > 0
		end
	end)
end

local function area_strengthen(entity, area, stat)
	for k, p in pairs(area) do
		local e = entity.map:get(p)
		if e and e.team == entity.team then
			if stat.speed then
				e.speed = e.speed + stat.speed
			end
			if stat.power then
				e.power = math.floor(e.power * stat.power)
			end
			if stat.resistance then
				core.strengthen(e, stat.resistance.value, stat.resistance.cap)
			end
			if stat.wet then
				e.status.wet = true
			end
		end
	end
end

local buff_strengthen = {
	name = "buff.haiyi.strengthen",

	tick = {{
		core.priority.pre_stat, function(self)
			local entity = self.owner
			if entity.status.ultimate then
				return true
			end

			local t
			if in_water(entity) then
				t = cfg.item.wand.water
			else
				t = cfg.item.wand.ground
			end

			if t.self then
				area_strengthen(entity, { entity.pos }, t.self)
			end
			if t.team then
				local area = hexagon.range(entity.pos, t.team.radius)
				-- exclude self
				table.remove(area, 1)
				local area = hexagon.adjacent(entity.pos)
				area_strengthen(entity, area, t.team)
			end

			return true
		end,
	}}
}

local buff_downpour = {
	name = "buff.haiyi.downpour",
	priority = core.priority.ultimate,
	duration = cfg.skill.downpour.duration,

	tick = {{
		core.priority.ultimate, function(self)
			local entity = self.owner
			entity.status.ultimate = true
			return true
		end,
	}, {
		core.priority.pre_stat, function(self)
			local entity = self.owner
			local t = cfg.skill.downpour
			if t.self then
				area_strengthen(entity, { entity.pos }, t.self)
			end
			if t.team then
				local area = hexagon.range(entity.pos, t.team.radius)
				-- exclude self
				table.remove(area, 1)
				area_strengthen(entity, area, t.team)
			end
			return true
		end,
	}, {
		core.priority.damage, function(self)
			local entity = self.owner
			local t = cfg.skill.downpour
			local area = hexagon.range(entity.pos, t.damage.radius)
			entity.map:damage(entity, area, t.damage, bubble_trigger, "wet", t.damage.wet_duration)

			area = hexagon.range(entity.pos, t.heal.radius)
			entity.map:heal(entity, area, t.heal, buff.insert, "wet", t.heal.wet_duration)

			return true
		end
	}}
}

local function new_bubble(strength, duration)
	local bubble = core.new_entity("entity.bubble", {
		health_cap = math.floor(cfg_bubble.health_ratio * strength),
		resistance = cfg_bubble.resistance,
		immune = cfg_bubble.immune,

		death = function(entity)
			local area = hexagon.range(entity.pos, cfg_bubble.damage.radius)
			entity.map:damage(entity, area, {
				damage = strength * cfg_bubble.damage.ratio,
				element = cfg_bubble.damage.element,
			}, buff.insert, "wet", cfg_bubble.damage.wet_duration)
		end,
	})
	bubble.ttl = duration
	buff.insert(bubble, {
		name = "buff.bubble.countdown",
		tick = {{
			core.priority.damage, function(self)
				local entity = self.owner
				if entity.ttl > 0 then
					entity.ttl = entity.ttl - 1
				else
					entity.map:kill(entity)
				end
				return true
			end,
		}}
	})
	return bubble
end

local skill_move = {
	name = "skill.haiyi.move",
	remain = 0,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.type = "target"
			util.merge_table(self, cfg.skill.move.water)

			self.use = function(self, target)
				local entity = self.owner
				local area = water_area(entity, self.step, true)
				if not util.find(area, target, hexagon.cmp) then
					return false
				end

				local res = core.teleport(entity, target)
				if res then
					entity.moved = true
				end

				return res
			end
		else
			self.type = "waypoint"
			util.merge_table(self, cfg.skill.move.ground)

			self.use = function(self, waypoint)
				local entity = self.owner
				if #waypoint == 0 or #waypoint > self.step then
					return false
				end

				local res = core.move(entity, waypoint)
				if res then
					entity.moved = true
				end

				return res
			end
		end
		self.enable = core.skill_update(self) and not entity.moved
	end,
}

local skill_attack = {
	name = "skill.haiyi.attack",
	type = "multitarget",
	remain = 0,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			util.merge_table(self, cfg.skill.attack.water)
		else
			util.merge_table(self, cfg.skill.attack.ground)
		end

		self.enable = core.skill_update(self) and check_water(self)
	end,
	use = function(self, target_list)
		local entity = self.owner

		if not core.multi_target(self, target_list, true) then
			return false
		end


		entity.map:damage(entity, target_list, util.merge_table(
			util.copy_table(self.damage), {
				ratio = self.damage.ratio / #target_list,
			}), bubble_trigger, "wet", self.damage.wet_duration)

		entity.map:heal(entity.team, target_list, {
			src_ratio = math.min(self.heal.src_ratio / #target_list, self.heal.limit),
		}, buff.insert, "wet", self.heal.wet_duration)

		consume_water(self)
		return true
	end,
}

local skill_convert = util.merge_table({
	name = "skill.haiyi.convert",
	type = "effect",
	remain = 0,
	item = "item.haiyi.wand",

	update = function(self)
		local entity = self.owner
		local wand = entity.inventory[1]
		local jellyfish = entity.inventory[2]
		self.enable = core.skill_update(self) and (jellyfish.water < jellyfish.water_cap) and (wand.remain == 0)
	end,
	use = function(self)
		local entity = self.owner
		local wand = entity.inventory[1]
		local jellyfish = entity.inventory[2]
		jellyfish.water = math.min(jellyfish.water + self.generate, jellyfish.water_cap)
		wand.remain = wand.cooldown
		return true
	end,
}, cfg.skill.convert)

local skill_bubble = {
	name = "skill.haiyi.bubble",
	type = "multitarget",
	remain = 0,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			util.merge_table(self, cfg.skill.bubble.water)
		else
			util.merge_table(self, cfg.skill.bubble.ground)
		end

		self.enable = core.skill_update(self) and check_water(self)
	end,

	use = function(self, target_list)
		local entity = self.owner

		if not core.multi_target(self, target_list, true) then
			return false
		end

		for i = 1, #target_list, 1 do
			local seed = {
				name = "seed.bubble",
				element = "water",
				team = entity.team,
				power = entity.power * self.bubble.ratio,
				pos = target_list[i],
				range = 0,
			}

			seed = entity.map:contact(seed)
			if seed then
				-- TODO storm spread bubbles
				local e = entity.map:get(seed.pos)
				if e then
					buff.insert(e, "bubble", entity.team, seed.power, self.bubble.duration)
				else
					entity.map:spawn(entity.team, new_bubble, seed.pos, seed.power, self.bubble.duration)
				end
			end
		end
		consume_water(self)
		return true
	end,
}

local skill_revive = {
	name = "skill.haiyi.revive",
	remain = 0,

	get_target = function(self, dir)
		local entity = self.owner
		if self.type == "direction" then
			return { hexagon.direction(entity.pos, dir) }
		elseif self.type == "effect" then
			return water_area(entity, self.step)
		else
			error(self.type)
		end
	end,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.type = "effect"
			util.merge_table(self, cfg.skill.revive.water)
		else
			self.type = "direction"
			self.step = nil
			util.merge_table(self, cfg.skill.revive.ground)

		end
		self.enable = core.skill_update(self) and check_water(self)
	end,
	use = function(self, ...)
		local entity = self.owner
		local tar = self:get_target(...)
		entity.map:heal(entity.team, tar, self.heal, buff.insert, "bubble", entity.team, entity.power * self.bubble.ratio, self.bubble.duration)
		consume_water(self)
		return true
	end,
}

local skill_downpour = util.merge_table({
	name = "skill.haiyi.downpour",
	type = "effect",
	remain = 0,

	update = function(self)
		self.enable = core.skill_update(self) and check_water(self)
	end,
	use = function(self)
		local entity = self.owner
		local info = util.merge_table(util.copy_table(self.rain), {
			team = entity.team,
			pos = entity.pos,
			power = entity.power * self.rain.power_ratio,
		})

		entity.map:layer_set("water", "downpour", info)
		consume_water(self)

		local area = hexagon.range(entity.pos, self.rain.radius)
		for k, p in pairs(area) do
			entity.map:layer_set("water", "depth", p, self.rain.depth)
		end

		buff.insert(entity, buff_downpour)
		return true
	end,
}, cfg.skill.downpour)

return function()
	local haiyi = core.new_character("entity.haiyi", cfg.template, {
		skill_move,
		skill_attack,
		skill_convert,
		skill_bubble,
		skill_revive,
		skill_downpour,
	})
	haiyi.quiver = quiver
	haiyi.free_ultimate = true

	table.insert(haiyi.inventory, {
		name = "item.haiyi.wand",
		cooldown = cfg.item.wand.cooldown,
		remain = 0,
		tick = core.common_tick,
	})

	table.insert(haiyi.inventory, {
		name = "item.haiyi.jellyfish",
		owner = haiyi,
		water = cfg.item.jellyfish.initial or 0,
		water_cap = cfg.item.jellyfish.water_cap,
		tick = function(self)
			local entity = self.owner
			if entity.status.ultimate then
				return
			end
			assert(cfg.item.jellyfish.range == 0, "jellyfish range other than 0 not implemented")
			local req = math.min(cfg.item.jellyfish.absorb, self.water_cap - self.water)
			local val = entity.map:layer_set("water", "depth", entity.pos, -req)
			if val then
				-- core.log(self.name .. " absorb " .. val .. " water")
				self.water = self.water + val
			end
		end,
	})

	buff.insert_notick(haiyi, buff_strengthen)

	return haiyi
end
