local box = require("gl/box")
local hexagon = require("gl/hexagon")

local function button_events(button, wnd, ev, info)
	if string.sub(ev, 1, 6) ~= "mouse_" then
		return
	end

	local hovered = button:bound(info.pos)
	if button.hover then
		button:hover(hovered)
	end

	if not hovered then
		return
	end

	if ev == "mouse_press" and button.press then
		button:press(info.button)
		return true
	elseif ev == "mouse_release" and button.release then
		button:release(info.button)
		return true
	end
end

local function new_button(button)
	button.handler = button_events
	if button.frame == "hexagon" then
		hexagon.new(button)
	elseif button.frame == "box" or not button.frame then
		box.new(button)
	else
		error("button: unknown frame type", button.frame)
	end

	if button.image then
		local mode = button.image.mode
		button.image.layer = button.image.layer or (button.layer + 1)
		button.image = button:add(button.image)
		-- FIXME scale for different modes

		local scale = 1
		if button.frame == "box" then
			scale = math.min(button.width / button.image.width, button.height / button.image.height)
		elseif button.frame == "hexagon" then
			scale = button.radius / math.min(button.image.width, button.image.height)
		end
		button.image.scale = button.image.scale * scale
	end

	if button.label then
		button.label.layer = button.label.layer or (button.layer + 2)
		button.label = button:add(button.label)
		-- TODO label alignment & placement
		if type(button.margin) == "number" then
			button.width = button.label.width + 2 * button.margin
			button.height = button.label.height + 2 * button.margin
		elseif type(button.margin) == "table" then
			button.width = button.label.width + 2 * button.margin[1]
			button.height = button.label.height + 2 * button.margin[2]
		end
	end

	return button
end


return {
	new = new_button,
}
