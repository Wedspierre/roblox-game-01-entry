local C = require(script.Parent.NeonConfig)
local G = {}
local FONT_TITLE = Enum.Font.Arcade
local FONT_BODY = Enum.Font.GothamBold
function G.newFrame(name: string, parent: Instance): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = C.Palette.Arena
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 12)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = C.Palette.Cyan
	s.Thickness = 2
	s.Transparency = 0.35
	s.Parent = f
	return f
end
function G.newLabel(name: string, parent: Instance, text: string, textSize: number, color: Color3, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.Font = font or FONT_BODY
	l.TextWrapped = true
	l.Parent = parent
	return l
end
function G.newTitleLabel(name: string, parent: Instance, text: string, textSize: number): TextLabel
	local l = G.newLabel(name, parent, text, textSize, C.Palette.Cyan, FONT_TITLE)
	local s = Instance.new("UIStroke")
	s.Color = C.Palette.Magenta
	s.Thickness = 1
	s.Transparency = 0.4
	s.Parent = l
	return l
end
function G.newButton(name: string, parent: Instance, text: string, fillColor: Color3, textSize: number?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = fillColor
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = textSize or 30
	b.TextColor3 = C.Palette.Background
	b.Font = FONT_TITLE
	b.AutoButtonColor = true
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = C.Palette.White
	s.Thickness = 2
	s.Transparency = 0.2
	s.Parent = b
	return b
end
function G.newDimLayer(name: string, parent: Instance): Frame
	local d = Instance.new("Frame")
	d.Name = name
	d.Size = UDim2.fromScale(1, 1)
	d.BackgroundColor3 = C.Palette.Background
	d.BackgroundTransparency = 0.45
	d.BorderSizePixel = 0
	d.Parent = parent
	return d
end
function G.newBar(name: string, parent: Instance, fillColor: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name .. "Back"
	back.BackgroundColor3 = C.Palette.Background
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = parent
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 6)
	bc.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 6)
	fc.Parent = fill
	return back, fill
end
return G
