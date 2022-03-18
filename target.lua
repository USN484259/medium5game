local core = require("core")

local template = {
	health_cap = 200,
	resistance = {

	},
}

return function(team, pos)
	return core.new_entity("target", team, pos, template)
end
