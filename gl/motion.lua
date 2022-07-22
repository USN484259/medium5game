local util = require("core/util")

local motion_table = {
	fade_in = function(target) return {
		tick = function(self, element, dist, time)
			element.color[4] = dist * (target or 1)

			return true
		end,
	} end,
	fade_out = function() return {
		init = function(self, element, time)
			self.origin = element.color[4]
		end,
		tick = function(self, element, dist, time)
			element.color[4] = (1 - dist) * self.origin

			return true
		end,
	} end,
	move = function(target) return {
		init = function(self, element, time)
			self.origin = element.pos
		end,
		tick = function(self, element, dist, time)
			element.pos = {
				self.origin[1] * (1 - dist) + target[1] * dist,
				self.origin[2] * (1 - dist) + target[2] * dist,
			}

			return true
		end,
	} end,
}

--[[
overrides:
	delay
	duration
	trigger
	watch
	done(self, element, time)
fixed:
	tick(self, element, dist, time)
	init(self, element, time)
status:
	timestamp
	signal
--]]
local function motion_new(name, override, ...)
	local motion = motion_table[name](...)
	return util.merge_table(motion, override or {})
end

local function motion_add(element, motion, time)
	motion.timestamp = time + (motion.delay or 0)
	if motion.init then
		motion:init(element, time)
	end
	table.insert(element.motion_list, 1, motion)
end

local function motion_apply(element, time)
	for i = #element.motion_list, 1, -1 do
		local motion = element.motion_list[i]
		local skip = false
		if motion.watch then
			if motion.watch.signalled then
				motion.watch = nil
				motion.timestamp = time + (motion.delay or 0)
				if motion.init then
					motion:init(element, time)
				end
			else
				-- continue
				skip = true
			end
		end
		if time >= motion.timestamp and not skip then
			local dist = math.min(1, (time - motion.timestamp) / motion.duration)
			local res = motion:tick(element, dist, time)
			if dist >= (motion.trigger or 1) then
				motion.signalled = true
			end
			if dist >= 1 or not res then
				motion.signalled = true
				if motion.done then
					motion:done(element, time)
				end
				table.remove(element.motion_list, i)
			end
		end
	end
end

return {
	new = motion_new,
	add = motion_add,
	apply = motion_apply,
}
