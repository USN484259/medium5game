#!/usr/bin/env lua

local util = require("util")

local map_scale = 5
local player_team = 1

local function show_map(map)
	print("--------map--------")
	local team = {}
	for k, e in pairs(map.entities) do
		local str = ""
		if e.team == player_team then
			table.insert(team, e)
			str = tostring(#team) .. '\t'
		else
			str = "-\t"
		end
		str = str .. "(" .. e.pos[1] .. "," .. e.pos[2] .. ")\t" .. e.name .. "\tHP " .. e.health .. '/' .. e.health_cap
		if e.energy then
			str = str .. "\tMP " .. e.energy .. '/' .. e.energy_cap
		end
		print(str)
	end

	return team
end

local function action_menu(entity)
	print("--------character--------")
	local str = entity.name .. "\tHP " .. entity.health .. '/' .. entity.health_cap .. '\tMP ' .. entity.energy .. '/' .. entity.energy_cap
	for k, v in pairs(entity.status) do
		str = str .. '\t' .. k
	end
	print(str)

	for k, item in pairs(entity.inventory) do
		local str = item.name .. '\t'
		if item.remain then
			str = str .. item.remain .. '/' .. item.cooldown
		elseif item.modes then
			for i = 1, #item.modes, 1 do
				local m = item.modes[i]
				if type(m) == "table" then
					m = m.name
				end
				if i == item.select then
					str = str .. '[' .. m .. "] "
				else
					str = str .. m .. ' '
				end
			end
		end
		print(str)
	end

	if not entity.active then
		print("not active, go back ...")
		return true
	end

	print("0\tGo back")
	for i = 1, #entity.skills, 1 do
		local sk = entity.skills[i]
		sk:update()

		local str = tostring(i) .. '\t' .. sk.name .. "\t" .. sk.type .. "\tCD " .. sk.remain .. '/' .. sk.cooldown .. "\tMP " .. (sk.cost) .. '\t'
		if sk.enable then
			str = str .. "enabled"
		else
			str = str .. "disabled"
		end
		print(str)
	end

	local sk
	local args
	while true do
		local cmd = io.read()
		sk = nil
		args = nil
		for s in string.gmatch(cmd, '([^%s]+)') do
			if args then
				local val = tonumber(s)
				table.insert(args, val or s)
			else
				local index = tonumber(s)
				if index == 0 then
					return true
				end
				sk = entity.skills[index]
				args = {}
			end
		end

		if sk then
			break
		end
	end

	local res
	if sk.type == "target" or sk.type == "waypoint" then
		res = entity:action(sk, args)
	elseif sk.type == "vector" then
		res = entity:action(sk, { args[1], args[2] }, args[3])
	else
		res = entity:action(sk, table.unpack(args))
	end

	if not res then
		print("skill " .. sk.name .. " failed")
	end

	return res and not entity.active
end

local function player_control(map)
	while true do
		local team = show_map(map)
		if #team == 0 then
			print("Game over")
			os.exit()
		elseif #team == #map.entities then
			print("You win")
			os.exit()
		end
		local selection = io.read("n")
		if math.type(selection) == "integer" then
			if selection == 0 then
				break
			elseif selection <= #team then
				while not action_menu(team[selection]) do end
			end
		end
	end

end

local function main()
	local map = require("map")(map_scale)

	map:spawn("shian", 1, {1, 0})
	map:spawn("chiyu", 1, {1, 1})
	map:spawn("cangqiong", 1, {0, 0})

	for n = 1, 10, 1 do
		local d = math.random(map_scale)
		local i = math.random(d * 6)
		map:spawn("target", 0, {d, i})
	end

	while true do
		map:tick(0)
		map:tick(1, player_control)
		-- map:tick(2, ai_control)
	end

end

main()
