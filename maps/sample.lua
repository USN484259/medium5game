return {
	scale = 8,

	layers = {{
		name = "light",

		-- energy sources
		{ pos = {2, 7}, energy = 100 },
	}, {
		name = "air",
	}, {
		name = "fire",
	}, {
		name = "water",

		-- ground water
		{ pos = {3, 14}, depth = 60 },
	}},

	teams = {{
		faction = "player",
		{ "shian", {1, 0}, {energy = 1000} },
		{ "chiyu", {1, 1} },
		{ "cangqiong", {1, 2} },
		{ "stardust", {1, 3} },
		{ "haiyi", {1, 4} },
	}, {
		{ "toolman", {0, 0} },
	}},
}
