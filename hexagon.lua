local function cmp(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

local function adjacent(pos)
	local d = pos[1]
	local i = pos[2]

	if d == 0 then
		return {
			{1, 0},
			{1, 1},
			{1, 2},
			{1, 3},
			{1, 4},
			{1, 5},
		}
	end

	local table
	local div = i // d
	local mod = i % d

	if mod == 0 then
		table = {
			{d + 1, div * (d + 1)},
			{d + 1, div * (d + 1) + 1},
			{d,	i + 1},
			{d - 1,	div * (d - 1)},
			{d,	i - 1},
			{d + 1,	div * (d + 1) - 1},
		}
	else
		table = {
			{d + 1, div * (d + 1) + mod},
			{d + 1, div * (d + 1) + mod + 1},
			{d,	i + 1},
			{d - 1,	div * (d - 1) + mod},
			{d - 1,	div * (d - 1) + mod - 1},
			{d,	i - 1},
		}
	end

	local res = {}

	for i = 0,5,1 do
		res[(i + div) % 6 + 1] = table[i + 1]
	end

	for i = 1,6,1 do
		if res[i][1] == 0 then
			res[i][2] = 0
		elseif res[i][2] < 0 then
			res[i][2] = res[i][2] + 6 * res[i][1]
		elseif res[i][2] // res[i][1] >= 6 then
			res[i][2] = res[i][2] - 6 * res[i][1]
		end
	end

	return res
end

local function direction(pos, dir)
	return adjacent(pos)[dir]
end

local function range(pos, dis)
	local res = { pos }
	local queue = { pos }

	while dis > 0 do
		local new_queue = nil
		local group = math.max(#queue // 6, 1)
		local last_element = nil

		for dir = 1,#queue, 1 do
			local adj = adjacent(queue[dir])
			for i = 5, 10, 1 do
				local p = adj[((dir - 1) // group + i) % 6 + 1]
				if not new_queue then
					new_queue = {}
					last_element = p
				elseif not util.find(res, p, cmp) then
					table.insert(new_queue, p)
					table.insert(res, p)
				end
			end
		end
		if #queue == 1 then
			table.insert(new_queue, last_element)
			table.insert(res, last_element)
		end
		queue = new_queue

		dis = dis - 1
	end

	return res
end

local function fan(pos, dis, dl, dr)
	local res = { pos }
	local queue = { pos }

	while dis > 0 do
		local new_queue = {}
		for i = 1, #queue, 1 do
			local dir = dl
			while true do
				local p = direction(queue[i], dir)
				if not util.find(res, p, cmp) then
					table.insert(new_queue, p)
					table.insert(res, p)
				end
				if dir == dr then
					break
				else
					dir = dir % 6 + 1
				end
			end
		end

		queue = new_queue
		dis = dis - 1
	end

	return res
end

return {
	cmp = cmp,
	adjacent = adjacent,
	direction = direction,
	range = range,
	fan = fan,
}
