local gl = require("moongl")

local vertex_shader = [[
#version 330 core

uniform vec4 scale;
uniform vec2 offset;
layout(location=0) in vec4 pos;
layout(location=1) in vec4 in_color;
out vec4 color;

void main()
{
	gl_Position = (vec4(offset, 0.0, 0.0) + pos) * scale;
	color = in_color;
}
]]

local fragment_shader = [[
#version 330 core

in vec4 color;
out vec4 out_color;

void main()
{
	out_color = color;
}
]]

local function adjacent(pos, dir, scale)
	local r = math.rad(60 * (dir - 1))
	return {
		pos[1] + scale * math.sqrt(3) * math.cos(r),
		pos[2] + scale * math.sqrt(3) * math.sin(r),
	}
end

local function make_points(ring, scale)
	local data = { {0, 0} }

	local point = {1, 0}
	local pos = adjacent({0, 0}, 1, scale)
	local direction = 3

	while point[1] <= ring do
		table.insert(data, pos)

		point[2] = point[2] + 1
		pos = adjacent(pos, direction, scale)

		if point[2] % point[1] == 0 then
			direction = direction % 6 + 1
		end
		if point[2] // point[1] == 6 then
			point[1] = point[1] + 1
			point[2] = 0
			pos = adjacent(pos, 1, scale)
			direction = 3
		end
	end

	return data
end

local function make_color(base, overlay)
	local data = {}
	table.move(base, 1, 4, 1, data)

	if not overlay or #overlay == 0 then
		for i = 0, 6, 1 do
			table.move(base, 1, 4, #data + 1, data)
		end
		return data
	end

	if #overlay <= 3 or #overlay >= 6 then
		for i = 0, 5, 1 do
			table.move(overlay[1 + i * #overlay // 6], 1, 4, #data + 1, data)
		end
	elseif #overlay == 4 then
		table.move(overlay[1], 1, 4, #data + 1, data)
		table.move(overlay[2], 1, 4, #data + 1, data)
		table.move(base, 1, 4, #data + 1, data)

		table.move(overlay[3], 1, 4, #data + 1, data)
		table.move(overlay[4], 1, 4, #data + 1, data)
		table.move(base, 1, 4, #data + 1, data)

	elseif #overlay == 5 then
		for i = 1, 5, 1 do
			table.move(overlay[i], 1, 4, #data + 1, data)
		end
		table.move(base, 1, 4, #data + 1, data)
	end
	table.move(overlay[1], 1, 4, #data + 1, data)

	return data
end

local function tile_index(pos)
	local d = pos[1]
	if d == 0 then
		return 0
	end

	return 3 * d * (d - 1) + pos[2] + 1
end

local prog
local loc_scale
local loc_offset

local function render(self, w, h)
	gl.use_program(prog)
	gl.bind_vertex_array(self.vertex)

	gl.bind_buffer("array", self.color_buffer)
	gl.uniform(loc_scale, "float", h / w, 1.0, 1.0, 1.0)
	gl.buffer_sub_data("array", 0, gl.pack("float", self.bg_color))


	for i, offset in ipairs(self.points) do
		local overlay = self.overlay[i - 1]

		gl.uniform(loc_offset, "float", table.unpack(offset))
		if overlay then
			local colors = make_color(self.bg_color, overlay)
			gl.buffer_sub_data("array", 0, gl.pack("float", colors))
		end

		gl.draw_arrays("triangle fan", 0, 8)

		if overlay then
			gl.buffer_sub_data("array", 0, gl.pack("float", self.bg_color))
		end

	end

	gl.buffer_sub_data("array", 0, gl.pack("float", self.line_color))

	for i, offset in ipairs(self.points) do
		gl.uniform(loc_offset, "float", table.unpack(offset))
		gl.draw_arrays("line loop", 1, 6)
	end

	gl.unbind_buffer("array")
	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function set(self, pos, color)
	local index = tile_index(pos)
	self.overlay[index] = color
end

local function new_map(ring, scale)
	if not prog then
		prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
		loc_scale = gl.get_uniform_location(prog, "scale")
		loc_offset = gl.get_uniform_location(prog, "offset")
	end

	local points = {0.0, 0.0, 0.0, 1.0}
	for i = 0, 6, 1 do
		local r = math.rad(60 * i - 30)
		local x = scale * math.cos(r)
		local y = scale * math.sin(r)
		local t = {x, y, 0.0, 1.0}

		table.move(t, 1, 4, 1 + #points, points)
	end

	local v = gl.new_vertex_array()

	local bp = gl.new_buffer("array")
	gl.buffer_data("array", gl.pack("float", points), "static draw")
	gl.vertex_attrib_pointer(0, 4, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(0)
	gl.unbind_buffer("array")

	local bc = gl.new_buffer("array")
	local bg_color = make_color({0.8, 0.8, 0.8, 1.0})
	gl.buffer_data("array", gl.pack("float", bg_color), "stream draw")
	gl.vertex_attrib_pointer(1, 4, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(1)
	gl.unbind_buffer("array")

	gl.unbind_vertex_array()

	local line_color = make_color({0.0, 0.0, 0.0, 1.0})
	local points = make_points(ring, scale)

	return {
		ring = ring,
		points = points,
		bg_color = bg_color,
		line_color = line_color,
		overlay = {},
		vertex = v,
		color_buffer = bc,
		set = set,
		render = render,
	}
end


return {	
	new_map = new_map,
}
