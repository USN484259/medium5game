local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

local function bubble_trigger(entity, buff_name, ...)
	local b = buff.remove(entity, "bubble")
	if b then
		core.damage(entity, {
			damage = b.power,
			element = "physical",
		})
	end

	if buff_name then
		buff.insert(entity, buff_name, ...)
	end
end

local template = {
	health_cap = 900,
	speed = 5,
	accuracy = 8,
	power = 60,
	sight = 3,
	energy_cap = 1000,
	generator = 100,
	moved = false,
	resistance = {
		physical = 0.2,
		fire = 0.3,
		water = 0.8,
		air = 0.2,
		earth = 0.1,
		star = 0,
		mental = 0.3,
	},
	immune = {
		drown = true,
	},
	quiver = {
		name = "water",
		cost = 30,
		single = function(entity, target)
			entity.map:damage(entity.team, { target }, {
				damage = 100,
				element = "water",
			}, bubble_trigger, "bubble", entity.team, 2)
		end,

		area = function(entity, area)
			entity.map:damage(entity.team, area, {
				damage = 200,
				element = "water",
			}, bubble_trigger, "bubble", entity.team, 2)

			entity.map:heal(entity.team, area, {
				ratio = 0.2,
				max_cap = 100,
			}, buff.insert, "bubble", entity.team, 2)
		end,
	},
	layer = "waters",
}

local swim_depth = 40

local function in_water(entity)
	local water = entity.map:layer("waters", entity.pos)
	return water and water > swim_depth
end

local function check_water(skill)
	local entity = skill.owner
	local req = skill.water_cost
	local stored_water = entity.inventory[2].water
	local ground_water = 0

	local area = hexagon.range(entity.pos, 1)
	for k, p in pairs(area) do
		ground_water = ground_water + (entity.map:layer("waters", p) or 0)
	end
	return stored_water + ground_water >= req
end

local function consume_water(skill)
	local entity = skill.owner
	local req = skill.water_cost
	local gound_water = true

	error "REVIEW"

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
			local val = entity.map:layer("waters", p)
			if val and val > 0 then
				count = count + 1
			end
		end

		local unit
		local val = entity.map:layer("waters", entity.pos)
		if val and val > 0 then
			unit = math.ceil(req / (count + 3))
			req = req - entity.map:layer("waters", entity.pos, math.min(req, 3 * unit))
			ground_water = true
		else
			unit = math.ceil(req / count)
		end

		for k, p in pairs(ring) do
			if req <= 0 then
				break
			end
			req = req - entity.map:layer("waters", p, unit)
			ground_water = true
		end
	end
end

local function water_area(entity, range, threshold, shore)
	threshold = threshold or 0
	return hexagon.connected(entity.pos, range, function(a, b)
		local w_a = entity.map:layer("waters", a)
		if w_a and w_a >= threshold then
			if shore then
				return true
			end

			local w_b = entity.map:layer("waters", b)
			return w_b and w_b >= threshold
		end
	end)
end

local skill_move = {
	name = "move",
	type = "waypoint",
	cooldown = 0,
	remain = 0,
	enable = true,
	cost = 20,
	step = 2,

	update = function(self, tick)
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
		self.enable = core.skill_update(self, tick) and not entity.moved
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

	update = function(self, tick)
		local entity = self.owner
		if in_water(entity) then
			self.shots = 4
			self.water_cost = 100
			self.range = 8
		else
			self.shots = 1
			self.water_cost = 20
			self.range = 3
		end

		self.enable = core.skill_update(self, tick) and check_water(self)
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
	cooldown = 1,
	remain = 0,
	enable = true,
	cost = 80,
	update = function(self, tick)
		local entity = self.owner
		local jellyfish = entity.inventory[2]
		self.enable = core.skill_update(self, tick) and (jellyfish.water < jellyfish.water_cap)
	end,
	use = function(self)
		local entity = self.owner
		local jellyfish = entity.inventory[2]
		jellyfish.water = math.min(jellyfish.water + 50, jellyfish.water_cap)
		return true
	end,
}

local skill_bubble = {
	name = "bubble",
	type = "target",
	cooldown = 2,
	remain = 0,
	enable = true,
	cost = 80,
	water_cost = 20,
	range = 2,

	update = function(self, tick)
		self.enable = core.skill_update(self, tick) and check_water(self)
	end,

	use = function(self, target)
		local entity = self.owner
		if not hexagon.distance(entity.pos, target, self.range) then
			return false
		end

		local seed = {
			name = "water",
			team = entity.team,
			power = entity.power,
			pos = target,
			range = 0,
		}

		seed = entity.map:contact(seed)
		if seed then
			local e = entity.map:get(seed.pos)
			if e then
				buff.insert(e, buff_bubble, entity.team, 2)
			else
				entity.map:spawn(entity.team, new_bubble, seed.pos)
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

	update = function(self, tick)
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
				}, buff.insert, "bubble", 2)
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
				}, buff.insert, "bubble", 2)
				consume_water(self)
				return true
			end
		end
		self.enable = core.skill_update(self, tick) and check_water(self)
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

	update = function(self, tick)
		self.enable = core.skill_update(self, tick) and check_water(self)
	end,
	use = function(self)
		local entity = self.owner
		local area = hexagon.range(entity.pos, self.range)
		entity.map:effect(entity.team, area, "downpour", downpour_duration)
		consume_water(self)
		entity.status.ultimate = true
		buff.insert(entity, buff_downpour)

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
		tick = function(self)
		end,
	})

	table.insert(haiyi.inventory, {
		name = "jellyfish",
		owner = haiyi,
		water = 0,
		water_cap = 800,
		tick = function(self)
			local entity = self.owner
			local req = math.min(self.water_cap // 8, self.water_cap - self.water)
			local val = entity.map:layer("waters", entity.pos, req)
			if val then
				core.log(self.name .. " absorb " .. val .. " water")
				self.water = self.water + val
			end
		end,
	})
	buff.insert(haiyi, buff_swimming)
	buff.insert(haiyi, buff_healing)

	return haiyi
end
