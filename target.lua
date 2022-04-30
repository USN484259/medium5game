local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

local template = {
	health_cap = 1000,
	resistance = {},
}

local buff_attack = {
	name = "attack",

	tick = {{
		core.priority.damage, function(self)
			local entity = self.owner
			local area = hexagon.adjacent(entity.pos)
			entity.map:damage(entity.team, area, {
				damage = 100,
				element = "physical",
				accuracy = 6,
			})
			return true
		end,
	}}
}

return function()
	local obj = core.new_entity("target", template)
	buff.insert(obj, buff_attack)
	return obj
end
