return {
	scale = 4,

	layers = {{
		name = "light",
	}, {
		name = "air",
	}, {
		name = "fire",
	}, {
		name = "water",

		{ pos = {3, 6}, depth = 1200 },
		{ pos = {3, 7}, depth = 2000 },
		{ pos = {3, 8}, depth = 2000 },
		{ pos = {3, 9}, depth = 1200 },
		{ pos = {4, 10}, depth = 1000 },
		{ pos = {2, 5}, depth = 1000 },
		{ pos = {4, 11}, depth = 800 },
		{ pos = {2, 6}, depth = 800 },
		{ pos = {4, 9}, depth = 800 },
		{ pos = {2, 4}, depth = 800 },
		{ pos = {4, 8}, depth = 500 },
		{ pos = {4, 7}, depth = 500 },
		{ pos = {3, 5}, depth = 500 },
		{ pos = {4, 12}, depth = 500 },
		{ pos = {3, 10}, depth = 500 },
		{ pos = {4, 13}, depth = 500 },

	}},

	teams = {{
		faction = "player",
		{ "haiyi", {0, 0}, {energy = 400} },
		{ "chiyu", {4, 10} },
	}, {
		{ "toolman", {2, 7} },
		{ "toolman", {4, 12} },
		{ "toolman", {2, 2} },
		round = function(map, tid, round)
			local team = map:get_team(tid)
			local actions = {}
			for k, e in ipairs(team) do
				for i, sk in ipairs(e.skills) do
					if sk.enable then
						table.insert(actions, {
							cmd = "use_skill",
							entity = e,
							skill = sk,
							args = nil,
						})
					end
				end
			end

			table.insert(actions, {
				cmd = "round_end",
			})

			return actions
		end,
	}},
}
