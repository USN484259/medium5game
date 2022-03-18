#!/usr/bin/env lua

local util = require("util")

local map_scale = 4

local function show_map(map)
	for k, e in pairs(map.entities) do
		local str = "(" .. e.pos[1] .. "," .. e.pos[2] .. ")\t" .. e.name .. "\tHP " .. e.health .. '/' .. e.health_cap
		if e.energy then
			str = str .. "\tMP " .. e.energy .. '/' .. e.energy_cap
		end
		print(str)
	end
end

local function ui(player)
	-- show skill
	print("0\tend round")
	for i = 1, #player.skills, 1 do
		local sk = player.skills[i]
		sk:update()

		local str = tostring(i) .. '\t' .. sk.name .. "\t" .. sk.type .. "\tCD " .. sk.remain .. '/' .. sk.cooldown .. "\tMP " .. (sk.cost or 0) .. '\t'
		if sk.enable then
			str = str .. "enabled"
		else
			str = str .. "disabled"
		end
		print(str)
	end
	local cmd = io.read()
	if not cmd then
		return false
	end
	local sk = nil
	local args = nil
	for s in string.gmatch(cmd, '([^%s]+)') do
		if args then
			local val = tonumber(s)
			table.insert(args, val or s)
		else
			local index = tonumber(s)
			if index == 0 then
				return true
			end
			sk = player.skills[index]
			args = {}

			if not sk then
				return false
			end
		end
	end

	local res
	
	local consume = (sk.cooldown > 0)

	if sk.type == "target" or sk.type == "waypoint" then
		res = sk:use(args)
	else
		res = sk:use(table.unpack(args))
	end
	
	return consume and res
	
end

local function main()
	local map = require("map")(map_scale)

	local player = map:spawn("shian", 1, {0, 0})

	for n = 1, 10, 1 do
		local d = math.random(map_scale)
		local i = math.random(d * 6)
		map:spawn("target", 0, {d, i})
	end

	while true do
		map:tick()
		if not player:alive() then
			break
		end

		show_map(map)

		while not ui(player) do end
	end

end

main()
