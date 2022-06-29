#!/usr/bin/env lua

local platform = require("lua_platform")

print("\x1B[38;2;192;192;64maaaaa\x1B[0m")
print("\x1B[38;5;128;1mbbbbbb\x1B[0m")

print(platform.uname())
print(platform.cwd())
local l = platform.ls("maps")
for k, v in pairs(l) do
	print(k, v)
end


local window = require("gui").new_window()

local gl_map = require("gl/map").new_map(4, 500)
window:add(gl_map)

local overlay = {
	{1.0, 0.0, 0.0, 0.4},
	{1.0, 1.0, 0.0, 0.4},
	{0.0, 1.0, 0.0, 0.4},
	{0.0, 1.0, 1.0, 0.4},
	{0.0, 0.0, 1.0, 0.4},
	{1.0, 0.0, 1.0, 0.4},
}

gl_map:set({1, 2}, overlay)

local gl_image = require("gl/image").new_image("resources/chiyu.png")

gl_image.scale = 4
gl_image.alpha = 0.6
gl_image.pos = {3800, 1800}

window:add(gl_image)

local str = "Hello测试World!"

local gl_text = require("gl/text").new_font("resources/wqy-zenhei.ttc", 256):new_text(str)

gl_text.scale = 2
gl_text.pos = {-5000, -4000}

window:add(gl_text)



while window:step() do end



--[[
local hexagon = require("hexagon")

local function dump(array)
	for k, v in pairs(array) do
		if type(v) == "table" then
			print(k, '{')
			dump(v)
			print('}')
		else
			print(k, v)
		end
	end
end

dump(hexagon.range({1, 1}, 2))
print("----")
dump(hexagon.fan({3, 3}, 3, 4, 6))
print("----")
dump(hexagon.line({2, 7}, 2, 6))
--]]
