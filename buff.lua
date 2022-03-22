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
			if not core.common_tick(self) then
				return false
			end
			core.damage(self.owner, {
				damage = self.damage,
				element = "fire",
			})
			return true
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


local list = {
	fly = fly,
	down = down,
	block = block,
	burn = burn,
	turbulence = turbulence,
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

	b.owner = entity

	table.insert(entity.buff, b)
	return true
end
