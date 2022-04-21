local util = require("util")

local function cmp(a, b)
	return a[1] == b[1] and a[2] == b[2]
end

local function direction(pos, dir)
	local d = pos[1]
	local i = pos[2]

	if d == 0 then
		return {1, (dir - 1) % 6}
	end

	local div = i // d
	local mod = i % d
	local table
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

	local index = (dir + 5 - div) % 6 + 1
	pos = table[index]

	if pos[1] == 0 then
		pos[2] = 0
	elseif pos[2] < 0 then
		pos[2] = pos[2] + 6 * pos[1]
	elseif pos[2] // pos[1] >= 6 then
		pos[2] = pos[2] - 6 * pos[1]
	end

	return pos
end

local function adjacent(pos)
	local res = {}

	for i = 1, 6, 1 do
		table.insert(res, direction(pos, i))
	end

	return res
end

local function walk_through(pos, limit, start, arc, func, ...)
	if not func(pos, 0, ...) then
		return
	end

	pos = direction(pos, start)
	local layer = 1
	local count = 0
	local turn = 0
	local dir = start + 2
	local anchor = pos

	while layer <= limit do
		--print("layer " .. layer, "count " .. count, "turn " .. turn, "dir " .. dir)
		if not func(pos, layer, ...) then
			return
		end
		pos = direction(pos, dir)
		count = count + 1

		if count // layer >= 6 or (arc < 6 and turn >= arc) then
			pos = direction(anchor, start)
			anchor = pos
			layer = layer + 1
			count = 0
			turn = 0
			dir = start + 2

		elseif count % layer == 0 then
			dir = dir + 1
			turn = turn + 1
		end




	end
end

local function ring(pos, dis, dl, dr)
	local res = {}
	local arc = 6

	if dl and dr then
		arc = dr - dl
	end

	walk_through(pos, dis, dl or 1, arc, function(pos, layer)
		if not res[layer] then
			res[layer] = {}
		end
		table.insert(res[layer], pos)
		return true
	end)
	return res
end

local function fan(pos, dis, dl, dr)
	local res = {}
	local arc = 6
	if dl and dr then
		arc = dr - dl
	end

	walk_through(pos, dis, dl or 1, arc, function(pos, layer)
		table.insert(res, pos)
		return true
	end)
	return res
end

local function distance(pos, tar, limit)
	local res = nil
	walk_through(pos, limit, 1, 6, function(pos, layer)
		if cmp(pos, tar) then
			res = layer
			return false
		end
		return true
	end)
	return res
end

local function line(pos, dir, limit)
	return fan(pos, limit, dir, dir)
end

local function range(pos, dis)
	return fan(pos, dis)
end

local function connected(pos, limit, judge)
	local res = { pos }
	local prev = { pos }

	for r = 1, limit, 1 do
		local cur = {}
		for i = 1, #prev, 1 do
			local adj = adjacent(prev[i])
			for j = 1, #adj, 1 do
				local p = adj[j]
				if not util.find(res, p, cmp) and judge(prev[i], p) then
					table.insert(res, p)
					table.insert(cur, p)
				end
			end
		end

		if #cur == 0 then
			break
		else
			prev = cur
		end
	end

	return res
end

return {
	print = function(p)
		return '(' .. p[1] .. ',' .. p[2] .. ')'
	end,
	cmp = cmp,
	direction = direction,
	adjacent = adjacent,
	ring = ring,
	distance = distance,
	fan = fan,
	line = line,
	range = range,
	connected = connected,
}
