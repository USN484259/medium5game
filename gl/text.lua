local gl = require("moongl")
local ft = require("moonfreetype")

local vertex_shader = [[
#version 330 core

uniform float aspect_ratio;
uniform vec2 scale;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec2 vertex_uv;
out vec2 uv;

void main()
{
	gl_Position = vec4((offset + pos * scale) / 0x1000, 0.0, 1.0) * vec4(aspect_ratio, 1.0, 1.0, 1.0);
	uv = vertex_uv;
}
]]

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

local function render(self, w, h)
	gl.use_program(prog)

	gl.uniform(loc_ratio, "float", h / w)

	gl.uniform(loc_color, "float", table.unpack(self.color))

	local base = {self.pos[1], self.pos[2]}

	gl.active_texture(1)
	gl.uniform(loc_texture, "int", 1)
	gl.bind_vertex_array(vertex_array)

	for i, g in ipairs(self.list) do
		gl.bind_texture("2d", g.texture)

		-- FIXME render based on CENTER of graph
		local scale = {
			self.scale * g.width / 2,
			self.scale * g.height / 2,
		}
		gl.uniform(loc_scale, "float", table.unpack(scale))

		local pos = {
			base[1] + self.scale * (g.left + g.width / 2),
			base[2] + self.scale * (g.top - g.height / 2),
		}

		gl.uniform(loc_offset, "float", table.unpack(pos))

		gl.draw_arrays("triangle strip", 0, 4)

		base[1] = base[1] + self.scale * g.advance
	end

	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function new_text(self, str)

	local list = {}
	for p, c in utf8.codes(str) do
		if not self.cp_table[c] then
			self.face:load_char(c, ft.LOAD_RENDER)
			local g = self.face:glyph()

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

			self.cp_table[c] = {
				texture = t,
				left = g.bitmap.left,
				top = g.bitmap.top,
				width = g.bitmap.width,
				height = g.bitmap.rows,
				stride = g.bitmap.pitch,
				advance = g.advance.x / 64,
			}

		end

		table.insert(list, self.cp_table[c])
	end

	return {
		str = str,
		list = list,
		scale = 1,
		pos = {0, 0},
		color = {0, 0, 0, 1},
		render = render,
	}
end

local function new_font(path, size)
	local face = ft.new_face(ft_lib, path)
	face:set_pixel_sizes(0, size or 64)

	return {
		face = face,
		size = size,
		cp_table = {},
		new_text = new_text,
	}
end

ft_lib = ft.init_freetype()

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

gl.pixel_store("unpack alignment", 1)

return {
	new_font = new_font,
}
