
local function animation_tick(element, t)
	local new_list = {}
	for i, v in ipairs(element.animation_list) do
		if v:tick(element, t) then
			table.insert(new_list, v)
		elseif v.done then
			v:done(element, t)
		end
	end
	element.animation_list = new_list
end

local function animation_add(element, timestamp, anime)
	anime.timestamp = timestamp
	table.insert(element.animation_list, anime)
end

local function animation_progress(anime, time)
	if anime.timestamp > time then
		return 0
	end

	return math.min(1, (time - anime.timestamp) / anime.duration)
end

local animation_list = {
	move = function(element, target, duration)
		return {
			pos = element.pos,
			target = target,
			duration = duration,
			tick = function(self, element, time)
				local dis = animation_progress(self, time)

				element.pos = {
					self.pos[1] * (1 - dis) + self.target[1] * dis,
					self.pos[2] * (1 - dis) + self.target[2] * dis,
				}

				return dis ~= 1
			end,
		}
	end,
	fade_in = function(element, duration)
		return {
			duration = duration,
			tick = function(self, element, time)
				local dis = animation_progress(self, time)
				if element.alpha then
					element.alpha = dis
				elseif element.color then
					element.color[4] = dis
				end

				return dis ~= 1
			end,
		}
	end,
	fade_out = function(element, duration)
		return {
			duration = duration,
			tick = function(self, element, time)
				local dis = animation_progress(self, time)
				if element.alpha then
					element.alpha = 1 - dis
				elseif element.color then
					element.color[4] = 1 - dis
				end

				return dis ~= 1
			end,
		}
	end,

}

return {
	coordinate_radix = 0x400,
	layer = {
		back = 0,
		common = 0x08,
		front = 0x0F,
--[[
		grid = 1,
		effect_under = 2,
		entity = 3,
		effect_over = 3,
		overlay = 4,
		gui = 5,
		front = 0x0F,
--]]
	},

	animation_tick = animation_tick,
	animation_add = animation_add,
	animation_progress = animation_progress,
	animation_list = animation_list,
}
