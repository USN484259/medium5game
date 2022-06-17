return {
	scale = 4,

	layers = {{
		name = "light",

		{ pos = {0, 0}, energy = 100 },
	}, {
		name = "air",
	}, {
		name = "fire",
	}, {
		name = "water",

		{ pos = {1, 2}, depth = 800 },
	}},

	teams = {{
		round = "player",
		{ "shian", {0, 0}, {energy = 400} },
		{ "haiyi", {1, 3} },
		{ "stardust", {1, 5} },
	}, {
		round = "enemy",
		{ "toolman", {1, 4} },
		{ "toolman", {2, 7}, 100 },
		{ "toolman", {2, 9}, 100 },
		round_end = function(map, tid, round)
			local list
			if round == 3 then
				list = {{
					{4, 12}, 500
				}, {
					{4, 11}, 100
				}, {
					{4, 13}, 100
				}}
			elseif round == 5 then
				list = {{
					{1, 2},
				}, {
					{1, 0},
				}, {
					{2, 1},
				}, {
					{2, 3},
				}, {
					{2, 5},
				}, {
					{2, 7},
				}, {
					{2, 9},
				}, {
					{2, 11},
				}}
			end

			if list then
				for i, v in ipairs(list) do
					map:spawn(tid, "toolman", v[1], v[2])
				end
			end
		end,
	}},
}
