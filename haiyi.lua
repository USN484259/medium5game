local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local swim_depth = 40
local downpour_duration = 3

local function bubble_trigger(entity, buff_name, ...)
	local b = buff.remove(entity, "bubble")
	if b then
		core.damage(entity, {
			damage = b.strength,
			element = "physical",
		})
	end

	if buff_name then
		buff.insert(entity, buff_name, ...)
	end

end

local template = {
	element = "water",
	health_cap = 900,
	speed = 5,
	accuracy = 8,
	power = 60,
	sight = 3,
	energy_cap = 1000,
	generator = 100,
	moved = false,
	free_ultimate = true,
	resistance = {
		physical = 0.2,
		fire = 0.3,
		water = 0.8,
		air = 0.2,
		earth = 0.1,
		ether = 0,
		mental = 0.3,
	},
	immune = {
		drown = true,
	},
	quiver = {
		name = "water",
		cost = 30,
		single = function(entity, target)
			entity.map:damage(entity.team, target, {
				damage = 100,
				element = "water",
			}, buff.insert, "bubble", entity.team, entity.power, 2)
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "water",
			}, buff.insert, "bubble", entity.team, entity.power, 2)

			entity.map:heal(entity.team, area, {
				ratio = 0.2,
				max_cap = 100,
			}, buff.insert, "bubble", entity.team, entity.power, 2)
		end,
	},
}

local buff_strengthen = {
	name = "strengthen",

	tick = {{
		core.priority.pre_stat, function(self)
			local entity = self.owner
			local area = hexagon.adjacent(entity.pos)

			for k, p in pairs(area) do
				local e = entity.map:get(p)
				if e and e.team == entity.team then
					if entity.status.ultimate then
						if e.speed > 0 then
							e.speed = e.speed + 2
						end
						core.strengthen(e, 0.2, 0.9)
						e.power = e.power * 5 // 4
					else
						if e.speed > 0 then
							e.speed = e.speed + 1
						end
						core.strengthen(e, 0.1, 0.8)
						e.power = e.power * 9 // 8
					end
					e.status.wet = true
				end
			end
			return true
		end,
	}}
}

local buff_downpour = {
	name = "downpour",
	priority = core.priority.ultimate,
	duration = downpour_duration,

	tick = {{
		core.priority.ultimate, function(self)
			local entity = self.owner
			entity.status.ultimate = true
			entity.power = entity.power * 2
			return true
		end,
	}, {
		core.priority.damage, function(self)
			local entity = self.owner
			local area = hexagon.range(entity.pos, 2)
			entity.map:damage(entity.team, area, {
				damage = entity.power / 2,
				element = "water",
				bubble_trigger = true,
			}, bubble_trigger, "wet", 2)

			entity.map:heal(entity.team, area, {
				heal = entity.power // 4,
			}, buff.insert, "wet", 2)

			return true
		end
	}}
}

local function in_water(entity)
	local water = entity.map:layer_get("water", entity.pos)
	return water and water > swim_depth
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
	-- error "REVIEW"
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
		local ring = hexagon.adjacent(entity.pos, 1)
		for k, p in pairs(ring) do
			local val = entity.map:layer_get("water", p)
			if val and val > 0 then
				count = count + 1
			end
		end

		local unit
		local val = entity.map:layer_get("water", entity.pos)
		if val and val > 0 then
			unit = math.ceil(req / (count + 3))
			req = req - entity.map:layer_set("water", "depth", entity.pos, - math.min(req, 3 * unit))
			ground_water = true
		else
			unit = math.ceil(req / count)
		end

		-- print("comsume_water " .. req .. '\t' .. unit)

		for k, p in pairs(ring) do
			if req <= 0 then
				break
			end
			req = req - (entity.map:layer_set("water", "depth", p, -unit) or 0)
			ground_water = true
		end
	end
end

local function water_area(entity, range, threshold, shore)
	threshold = threshold or 0
	return hexagon.connected(entity.pos, range, function(a, b)
		local w_a = entity.map:layer_get("water", a)
		if w_a and w_a >= threshold then
			if shore then
				return true
			end

			local w_b = entity.map:layer_get("water", b)
			return w_b and w_b >= threshold
		end
	end)
end

local function new_bubble()
	local bubble = core.new_entity("bubble_entity", {
		health_cap = 100,
		resistance = {
			water = 0.4,
			fire = -0.2,
		},
		immune = {
			drown = true,
			bubble = true,
		},
		hook = {{
			name = "bubble_trigger",
			priority = core.priority.first,
			func = function(self, entity, damage)
				if damage.bubble_trigger then
					entity.map:kill(entity)
					return nil
				end
				return damage
			end,
		}},
		death = function(entity)
			entity.map:damage(0, hexagon.adjacent(entity.pos), {
				damage = 60,
				element = "water",
			}, buff.insert, "wet", 1)
		end,
	})
	bubble.ttl = 4
	buff.insert(bubble, {
		name = "bubble_countdown",
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
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 20,
	step = 2,
	power_req = 20,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.type = "target"
			self.cost = 10
			self.step = 8
			self.use = function(self, target)
				local entity = self.owner
				local area = water_area(entity, self.step, swim_depth, true)
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
			self.cost = 20
			self.step = 2
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
	name = "attack",
	type = "multitarget",
	shots = 1,
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 40,
	water_cost = 20,
	range = 3,
	power_req = 20,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.shots = 4
			self.water_cost = 100
			self.range = 6
		else
			self.shots = 1
			self.water_cost = 20
			self.range = 3
		end

		self.enable = core.skill_update(self) and check_water(self)
	end,
	use = function(self, target_list)
		local entity = self.owner

		if not core.multi_target(self, target_list, true) then
			return false
		end

		local pwr = self.shots / #target_list

		entity.map:damage(entity.team, target_list, {
			damage = entity.power * pwr,
			element = "water",
			accuracy = entity.accuracy,
			bubble_trigger = true,
		}, bubble_trigger, "wet", 2)

		entity.map:heal(entity.team, target_list, {
			heal = entity.power * math.min(pwr, 2),
		}, buff.insert, "wet", 2)

		consume_water(self)
		return true
	end,
}

local skill_convert = {
	name = "convert",
	type = "effect",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 80,
	power_req = 8,

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
		jellyfish.water = math.min(jellyfish.water + 50, jellyfish.water_cap)
		wand.remain = wand.cooldown
		return true
	end,
}

local skill_bubble = {
	name = "make_bubble",
	type = "multitarget",
	shots = 1,
	cooldown = 2,
	remain = 0,
	enable = true,
	cost = 80,
	water_cost = 30,
	range = 2,
	power_req = 30,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.shots = 2
			self.water_cost = 50
			self.range = 4
		else
			self.shots = 1
			self.water_cost = 30
			self.range = 2
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
				name = "water",
				team = entity.team,
				power = entity.power,
				pos = target_list[i],
				range = 0,
			}

			seed = entity.map:contact(seed)
			if seed then
				local e = entity.map:get(seed.pos)
				if e then
					buff.insert(e, "bubble", entity.team, entity.power, 2)
				else
					entity.map:spawn(0, new_bubble, seed.pos)
				end
			end
		end
		consume_water(self)
		return true
	end,
}

local skill_revive = {
	name = "revive",
	type = "direction",
	cooldown = 8,
	remain = 0,
	enable = true,
	cost = 200,
	water_cost = 120,
	power_req = 30,

	update = function(self)
		local entity = self.owner
		if in_water(entity) then
			self.type = "effect"
			self.range = 8
			self.use = function(self)
				local entity = self.owner
				local area = water_area(entity, self.range)

				entity.map:heal(entity.team, area, {
					ratio = 0.4,
					overcap = true,
				}, buff.insert, "bubble", entity.team, 2 * entity.power, 2)
				consume_water(self)
				return true
			end
		else
			self.type = "direction"
			self.range = nil
			self.use = function(self, direction)
				local entity = self.owner
				local tar = hexagon.direction(entity.pos, direction)
				entity.map:heal(entity.team, { tar }, {
					ratio = 0.4,
					overcap = true,
				}, buff.insert, "bubble", entity.team, entity.power, 2)
				consume_water(self)
				return true
			end
		end
		self.enable = core.skill_update(self) and check_water(self)
	end,
}

local skill_downpour = {
	name = "downpour",
	type = "effect",
	cooldown = 12,
	remain = 0,
	enable = true,
	cost = 300,
	water_cost = 800,
	range = 4,

	update = function(self)
		self.enable = core.skill_update(self) and check_water(self)
	end,
	use = function(self)
		local entity = self.owner
		local area = hexagon.range(entity.pos, self.range)
		entity.map:layer_set("water", "downpour", entity.team, area, downpour_duration, entity.power)
		consume_water(self)
		buff.insert(entity, buff_downpour)

		for k, p in pairs(area) do
			entity.map:layer_set("water", "depth", p, 10)
		end

		return true
	end,
}

return function()
	local haiyi = core.new_character("haiyi", template, {
		skill_move,
		skill_attack,
		skill_convert,
		skill_bubble,
		skill_revive,
		skill_downpour,
	})

	table.insert(haiyi.inventory, {
		name = "wand_of_sea",
		cooldown = 1,
		remain = 0,
		tick = core.common_tick,
	})

	table.insert(haiyi.inventory, {
		name = "jellyfish",
		owner = haiyi,
		water = 0,
		water_cap = 800,
		tick = function(self)
			local entity = self.owner
			if entity.status.ultimate then
				return
			end
			local req = math.min(self.water_cap // 8, self.water_cap - self.water)
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
