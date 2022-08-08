local gl = require("moongl")
local ft = require("moonfreetype")
local misc = require("gl/misc")
local motion = require("gl/motion")
local util = require("core/util")

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

local function render(self, aspect_ratio)
	if not self.list then return end

	gl.use_program(prog)
	gl.uniform(loc_ratio, "float", aspect_ratio)

	gl.uniform(loc_color, "float", table.unpack(self.color))

	local base = {self.pos[1] - self.scale * self.width / 2, self.pos[2] + self.scale * self.base}

	gl.active_texture(1)
	gl.uniform(loc_texture, "int", 1)
	gl.bind_vertex_array(vertex_array)

	for i, g in ipairs(self.list) do
		local scale = self.scale * (self.size / g.face.size.size)

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
	local left = self.pos[1] - self.scale * self.width / 2
	local right = self.pos[1] + self.scale * self.width / 2

	local top = self.pos[2] + self.scale * self.height / 2
	local bot = self.pos[2] - self.scale * self.height / 2

	return pos[1] > left and pos[1] < right and pos[2] > bot and pos[2] < top
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

local function set_text(self, str, size)
	size = size or self.size or 64
	self.list = nil

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
						face = f,
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
				local scale = size / f.size.size
				length = length + scale * g.advance
				table.insert(list, g)

				if ascender then
					ascender, descender, height = math.max(ascender, scale * f.size.ascender), math.min(descender, scale * f.size.descender), math.max(height, scale * f.size.height)
				else
					ascender, descender, height = scale * f.size.ascender, scale * f.size.descender, scale * f.size.height
				end

				break
			end
		end
	end

	local offset = (ascender + descender) / 2

	util.merge_table(self, {
		str = str,
		size = size,
		list = list,
		width = length,
		height = height / 64 or 0,
		base = -offset / 64 or 0,
	})
end

local function new_text(element)
	gl_setup()

	if element.str then
		set_text(element, element.str, element.size)
	end

	return util.merge_table(element, {
		set_text = set_text,
		render = render,
		bound = bound,
	}, {
		scale = 1,
		pos = {0, 0},
		color = {0, 0, 0, 1},
	})
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
	new = new_text,
}
