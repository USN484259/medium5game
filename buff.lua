local util = require("util")
local core = require("core")

local function fly()
	return {
		name = "fly",
		priority = core.priority.stat,
		tick = function(self)
			self.owner.status.fly = true
			return true
		end,
	}
end

local function down(duration)
	return {
		name = "down",
		priority = core.priority.post_stat,
		duration = duration,
		tick = function(self)
			if not core.common_tick(self) then
				return false
			end
			if not self.owner.status.ultimate then
				self.owner.status.down = true
				self.owner.status.fly = nil
			end
			self.owner.speed = 0
			return true
		end,
	}
end

local function block(duration)
	return {
		name = "block",
		priority = core.priority.stat,
		duration = duration,
		tick = function(self)
			if not core.common_tick(self) then
				return false
			end
			self.owner.status.block = true
			if self.owner.speed then
				self.owner.speed = math.floor(self.owner.speed / 2)
			end
			return true
		end,
	}
end

local function burn(duration, damage)
	return {
		name = "burn",
		priority = core.priority.damage,
		duration = duration,
		damage = damage or 40,
		tick = function(self)
			local entity = self.owner
			if not core.common_tick(self) then
				return false
			end
			core.damage(entity, {
				damage = self.damage,
				element = "fire",
			})
			entity.status.burn = true
			return true
		end,
	}
end

local function cooling()
	return {
		name = "cooling",
		priority = core.priority.stat,
		tick = function(self)
			self.owner.status.cooling = true
			return false
		end,
	}
end

local function turbulence(damage)
	return {
		name = "turbulence",
		priority = core.priority.damage,
		damage = damage,

		tick = function(self)
			core.damage(self.owner, {
				damage = self.damage,
				element = "air",
				type = "air",
			})
			return false
		end,
	}
end

local function blackhole(strength)
	return {
		name = "blackhole",
		priority = core.priority.damage,
		strength = strength,

		tick = function(self)
			local entity = self.owner
			local cap = entity.health_cap
			core.damage(entity, {
				damage = math.max(self.strength * 5, cap * self.strength / 100),
				element = "physical",
			})
			return false
		end,
	}
end

local list = {
	fly = fly,
	down = down,
	block = block,
	burn = burn,
	cooling = cooling,
	turbulence = turbulence,
	blackhole = blackhole,
}

return function(entity, name, ...)
	local b
	if type(name) == "string" then
		b = list[name](...)
	elseif type(name) == "table" then
		b = util.copy_table(name)
	end
	if not b then
		return false
	end
	if b.unique then
		for k, v in pairs(entity.buff) do
			if v.name == b.name then
				return false
			end
		end
	end

	b.owner = entity
	table.insert(entity.buff, b)
	return true
end
