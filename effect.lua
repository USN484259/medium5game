local util = require("util")
local hexagon = require("hexagon")
local core = require("core")
local buff = require("buff")

-- TODO effect merge & react

local function effect_tick(f)
	if self.duration then
		if self.duration <= 0 then
			return false
		else
			self.duration = self.duration - 1
		end
	end
	return true
end


local function flame(duration, damage)
	return {
		name = "flame",
		priority = 1,
		duration = duration,
		damage = damage,
		apply = function(self, entity)
			if entity.team ~= self.team then
				buff(entity, "burn", 1, self.damage)
			end

			return true
		end,
		contact = function(self, obj)
			--TODO
			return obj
		end,
	}
end

local function wind(direction, duration)
	return {
		name = "wind",
		priority = 1,
		duration = duration,
		direction = direction,
		contact = function(self, obj)
			obj.pos = hexagon.direction(obj.pos, self.direction)
			return obj
		end,

	}
end

local function storm(center, range, duration)
	return {
		name = "storm",
		priority = 1,
		duration = duration,
		center = center,
		range = range,
		apply = function(self, entity)
			if entity.team ~= self.team then
				buff(entity, "turbulence", 200)
			end

			return true
		end,
		contact = function(self, obj)
			if obj.team ~= self.team then
				obj.power = obj.power / 2
			end
			obj.pos = self.center
			obj.range = self.range
			return obj
		end,
	}
end

local list = {
	flame = flame,
	wind = wind,
	storm = storm,
}

return function(name, ...)
	if not list[name] then
		return nil
	end
	return list[name](...)
end
