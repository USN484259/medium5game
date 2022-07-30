local util = require("core/util")

local motion_table

--[[

-- static
name : string
args : table
duration : number, opt
next : table

-- psudo
watch : number, opt

-- active
timestamp : number
tick : function(self, element, time, dist)

--]]

local function motion_add(element, motion_list, line_index)
	line_index = line_index or 1

	local root, prev
	root = element.motion_list[line_index]
	prev = root

	for i, v in ipairs(motion_list) do
		local m = {
			name = v.name,
			args = v.args or {},
			duration = v.duration,
			next = {},
		}

		if v.watch then
			if v.watch == 0 then
				prev = root
			else
				prev = motion_list[v.watch].instance
			end
		end
		if prev then
			table.insert(prev.next, m)
		else
			table.insert(element.motion_list, m)
		end

		v.instance = m
		prev = m
	end
end

local function motion_clear(element)
	element.motion_list = {}
end

local function motion_apply(element, time)
	local new_list = {}
	local count = #element.motion_list

	for i, m in ipairs(element.motion_list) do
		if not m.timestamp then
			util.merge_table(m, motion_table[m.name](element, table.unpack(m.args)))
			m.timestamp = time
		end

		local dist

		if m.duration then
			if m.duration == 0 then
				dist = 1
			else
				dist = math.min(1, (time - m.timestamp) / m.duration)
			end
		end

		if (not m:tick(element, time, dist)) or (dist and dist >= 1) then
			table.move(m.next, 1, #m.next, 1 + #new_list, new_list)
		else
			table.insert(new_list, m)
		end
	end

	element.motion_list = new_list

	return count
end

motion_table = {
	delay = function(e) return {
		tick = function() return true end
	} end,
	signal = function(e) return {
		tick = function(self, element, time, dist)
			element:signal()

			return false
		end,
	} end,
	remove = function(e) return {
		tick = function(self, element, time, dist)
			element.window:schedule(function()
				element.parent:remove(element)
			end)

			return false
		end,
	} end,
	overlay = function(parent, element_info, motion_list)
		local e = parent:add(element_info)
		motion_add(e, motion_list)
		return {
			child = e,
			tick = function(self, element, time, dist)
				return not self.child:is_signalled()
			end,
		}
	end,

	fade_in = function(e, target) return {
		tick = function(self, element, time, dist)
			element.color[4] = dist * (target or 1)

			return true
		end,
	} end,
	fade_out = function(e) return {
		origin = e.color[4],
		tick = function(self, element, time, dist)
			element.color[4] = (1 - dist) * self.origin

			return true
		end,
	} end,
	move = function(e, target) return {
		origin = e.pos,
		tick = function(self, element, time, dist)
			element.pos = {
				self.origin[1] * (1 - dist) + target[1] * dist,
				self.origin[2] * (1 - dist) + target[2] * dist,
			}

			return true
		end,
	} end,
}

return {
	add = motion_add,
	clear = motion_clear,
	apply = motion_apply,
}
