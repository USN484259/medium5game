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
		round = "player",
		{ "haiyi", {0, 0}, {energy = 400} },
		{ "chiyu", {4, 10} },
	}, {
		round = "enemy",
		{ "toolman", {2, 7} },
		{ "toolman", {4, 12} },
		{ "toolman", {2, 2} },
	}},
}
