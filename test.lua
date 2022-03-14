#!/usr/bin/env lua

util = require("util")
--core = require("core")
hexagon = require("hexagon")
map = require("map")(10)


local function show_pos(pos)
	return "(" .. pos[1] .. "," .. pos[2] .. ")"
end


map:spawn("player", 1, {0, 0})

for i=1,10,1 do
	local d = math.random(10)
	local i = math.random(6 * d) - 1
	map:spawn("target", 0, {d, i})
end

local player = map:get({0, 0})

while true do
	map:tick()

	-- look around
	local sight = hexagon.range(player.pos, player.sight)
	for k, p in pairs(sight) do
		local tar = map:get(p)
		if tar then
			print(tar.name .. " at " .. show_pos(tar.pos) .. " hp " .. tar.health)
		end
	end

	print("Select action:")
	local res
	repeat
		local str = io.read()
		if not str then
			return
		end
		local sep = string.find(str, " ", 1, true)

		local cmd = string.sub(str, 1, sep - 1)
		local arg = tonumber(string.sub(str, sep + 1))

		if cmd == "move" then
			res = player.skills[1].func(player, { arg })
		elseif cmd == "attack" then
			res = player.skills[2].func(player, {direction = arg, damage = 100})
		end
	until res
	print("Round end")
end

--[[
--util.dump_table(hexagon.range({0, 0}, 0))

local game = map.new_map(5)

local target = core.new_entity()
local player = core.new_character(1)

game:place(target, {4, 2})
game:place(player, {0, 0})

--util.dump_table(hexagon.fan({2, 3}, 3, 5, 1))

player.skills[1].func(game, player, {1, 1, 1})

util.dump_table(player.pos)

player.skills[2].func(game, player, {
	distance = 2,
	width = 2,
	direction = 3,
	damage = 40,
})

util.dump_table(player)
util.dump_table(target)

--]]
