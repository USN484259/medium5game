local gl = require("moongl")
local ft = require("moonfreetype")
local misc = require("gl/misc")
local motion = require("gl/motion")

local vertex_shader = string.format([[
#version 330 core

uniform float aspect_ratio;
uniform vec2 scale;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec2 vertex_uv;
out vec2 uv;

void main()
{
	gl_Position = vec4((offset + pos * scale) / %d, 0.0, 1.0) * vec4(aspect_ratio, 1.0, 1.0, 1.0);
	uv = vertex_uv;
}
]], misc.coordinate_radix)

local fragment_shader = [[
#version 330 core

uniform sampler2D tex;
uniform vec4 color;
in vec2 uv;
out vec4 out_color;

void main()
{
	out_color = color * vec4(1.0, 1.0, 1.0, texture(tex, uv).r);
}
]]

local prog
local vertex_array
local loc_ratio
local loc_scale
local loc_offset
local loc_texture
local loc_color

local ft_lib
local faces = {}

local function render(self, t, w, h)
	motion.apply(self, t)

	if self.hidden then
		return
	end

	gl.use_program(prog)
	gl.uniform(loc_ratio, "float", h / w)
	gl.uniform(loc_color, "float", table.unpack(self.color))

	local base = {self.pos[1], self.pos[2]}
	local align = self.align or "center"
	if align == "left" then
		-- noop
	elseif align == "right" then
		base[1] = base[1] - self.scale * self.length
	else
		if align ~= "center" then
			print("WARN", "unknown alignment " .. align)
		end

		base[1] = base[1] - self.scale * self.length / 2
	end

	gl.active_texture(1)
	gl.uniform(loc_texture, "int", 1)
	gl.bind_vertex_array(vertex_array)

	for i, g in ipairs(self.list) do
		local scale = self.scale * g.scale

		gl.bind_texture("2d", g.texture)

		local tx_scale = {
			scale * g.width / 2,
			scale * g.height / 2,
		}
		gl.uniform(loc_scale, "float", table.unpack(tx_scale))

		local tx_pos = {
			base[1] + scale * (g.left + g.width / 2),
			base[2] + scale * (g.top - g.height / 2),
		}

		gl.uniform(loc_offset, "float", table.unpack(tx_pos))

		gl.draw_arrays("triangle strip", 0, 4)

		base[1] = base[1] + scale * g.advance
	end

	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function bound(self, pos)
	local top = self.pos[2] + self.scale * self.ascender
	local bot = self.pos[2] + self.scale * self.descender

	if pos[2] <= bot or pos[2] >= top then
		return false
	end

	local x
	if self.align == "left" then
		left = self.pos[1]
	elseif self.align == "right" then
		x = self.pos[1] - self.scale * self.length
	else
		x = self.pos[1] - self.scale * self.length / 2
	end

	return pos[1] > x and pos[1] < (x + self.scale * self.length)
end

local function gl_setup()
	if not prog then
		local points = {
			-1.0, -1.0,
			1.0, -1.0,
			-1.0, 1.0,
			1.0, 1.0,
		}

		local uv = {
			0.0, 1.0,
			1.0, 1.0,
			0.0, 0.0,
			1.0, 0.0,
		}

		prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
		loc_ratio = gl.get_uniform_location(prog, "aspect_ratio")
		loc_scale = gl.get_uniform_location(prog, "scale")
		loc_offset = gl.get_uniform_location(prog, "offset")
		loc_texture = gl.get_uniform_location(prog, "tex")
		loc_color = gl.get_uniform_location(prog, "color")

		vertex_array = gl.new_vertex_array()

		local bp = gl.new_buffer("array")
		gl.buffer_data("array", gl.pack("float", points), "static draw")
		gl.vertex_attrib_pointer(0, 2, "float", false, 0, 0)
		gl.enable_vertex_attrib_array(0)
		gl.unbind_buffer("array")

		local bv = gl.new_buffer("array")
		gl.buffer_data("array", gl.pack("float", uv), "static draw")
		gl.vertex_attrib_pointer(1, 2, "float", false, 0, 0)
		gl.enable_vertex_attrib_array(1)
		gl.unbind_buffer("array")

		gl.unbind_vertex_array()
	end
end

local function new_text(str, size)
	gl_setup()

	local list = {}
	local length = 0
	local ascender, descender, height

	for p, c in utf8.codes(str) do
		for i, f in ipairs(faces) do
			if not f.cp_table[c] then
				local index = ft.get_char_index(f.face, c)
				if index and pcall(ft.load_glyph, f.face, index, ft.LOAD_RENDER) then
					local g = f.face:glyph()

					local t = gl.new_texture("2d")
					-- FIXME using pitch instead of width
					gl.texture_image("2d", 0, "red", "red", "ubyte", g.bitmap.buffer, g.bitmap.width, g.bitmap.rows)
					gl.texture_parameter("2d", "base level", 0)
					gl.texture_parameter("2d", "max level", 0)
					gl.texture_parameter('2d', 'wrap s', 'repeat')
					gl.texture_parameter('2d', 'wrap t', 'repeat')
					gl.texture_parameter('2d', 'min filter', 'linear')
					gl.texture_parameter('2d', 'mag filter', 'linear')

					gl.unbind_texture("2d")

					f.cp_table[c] = {
						texture = t,
						scale = size / f.size.size,
						left = g.bitmap.left,
						top = g.bitmap.top,
						width = g.bitmap.width,
						height = g.bitmap.rows,
						stride = g.bitmap.pitch,
						advance = g.advance.x / 64,
					}

				end
			end

			local g = f.cp_table[c]
			if g then
				length = length + g.scale * g.advance
				table.insert(list, g)

				if ascender then
					ascender, descender, height = math.max(ascender, f.size.ascender), math.min(descender, f.size.descender), math.max(height, f.size.height)
				else
					ascender, descender, height = f.size.ascender, f.size.descender, f.size.height
				end

				break
			end
		end
	end
	print(ascender, descender, height)
	return {
		layer = misc.layer.front,
		str = str,
		list = list,
		length = length,
		ascender = ascender / 64 or 0,
		descender = descender / 64 or 0,
		height = height / 64 or 0,
		scale = 1,
		pos = {0, 0},
		color = {0, 0, 0, 1},
		render = render,
		bound = bound,
		motion_list = {},
	}
end


local function add_face(path, size)
	size = size or 64
	local face = ft.new_face(ft_lib, path)
	print(path, "num_faces: " .. face:num_faces(), "bold: " .. tostring(face:is_bold()), "italic: " .. tostring(face:is_italic()))
	if face:num_fixed_sizes() == 0 then
		face:set_pixel_sizes(0, size)
	else
		-- FIXME find closest size
		face:select_size(1)

		size = face:available_sizes()[1].size / 64
	end

	local size_info = face:size()
	size_info.size = size
	print(size, size_info.height / 64, size_info.ascender / 64, size_info.descender / 64)

	table.insert(faces, {
		face = face,
		size = size_info,
		cp_table = {},
	})
end

ft_lib = ft.init_freetype()

return {
	add_face = add_face,
	new_text = new_text,
}
