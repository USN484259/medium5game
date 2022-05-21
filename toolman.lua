local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

local template = {
	health_cap = 1000,
	energy = 0,
	resistance = {},
}

return function()
	local obj = core.new_character("toolman", template, {{
		name = "attack",
		type = "effect",
		cooldown = 1,
		remain = 0,
		enable = true,
		cost = 0,

		update = core.skill_update,
		use = function(self)
			local entity = self.owner
			local area = hexagon.adjacent(entity.pos)
			entity.map:damage(entity.team, area, {
				damage = 100,
				element = "physical",
				accuracy = 6,
			})

			return true
		end,
	}})
	return obj
end
