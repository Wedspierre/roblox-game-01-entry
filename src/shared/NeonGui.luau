-- NeonGui: the shared neon look. Every screen the client builds goes
-- through these helpers so the palette, corners, glow and text size stay
-- identical across the start screen, the HUD, the pause and the end screen.

local NeonConfig = require(script.Parent.NeonConfig)

local NeonGui = {}

local FONT_TITLE = Enum.Font.Arcade
local FONT_BODY = Enum.Font.GothamBold

-- A plain full-bleed frame with no corner and no outline (backgrounds).
function NeonGui.newPlainFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = NeonConfig.Palette.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

function NeonGui.newFrame(name: string, parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = NeonConfig.Palette.Arena
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = NeonConfig.Palette.Cyan
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.Parent = frame
	return frame
end

function NeonGui.newLabel(
	name: string,
	parent: Instance,
	text: string,
	textSize: number,
	color: Color3,
	font: Enum.Font?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.Font = font or FONT_BODY
	label.TextWrapped = true
	label.Parent = parent
	return label
end

function NeonGui.newTitleLabel(name: string, parent: Instance, text: string, textSize: number): TextLabel
	local label = NeonGui.newLabel(name, parent, text, textSize, NeonConfig.Palette.Cyan, FONT_TITLE)
	local stroke = Instance.new("UIStroke")
	stroke.Color = NeonConfig.Palette.Magenta
	stroke.Thickness = 1
	stroke.Transparency = 0.4
	stroke.Parent = label
	return label
end

-- A glowing neon button: bright fill, thick outline, big readable text.
function NeonGui.newButton(
	name: string,
	parent: Instance,
	text: string,
	fillColor: Color3,
	textSize: number?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.BackgroundColor3 = fillColor
	button.BorderSizePixel = 0
	button.Text = text
	button.TextSize = textSize or 30
	button.TextColor3 = NeonConfig.Palette.Background
	button.Font = FONT_TITLE
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Color = NeonConfig.Palette.White
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = button
	return button
end

-- A full-screen dim layer behind a menu so the arena stays visible.
function NeonGui.newDimLayer(name: string, parent: Instance): Frame
	local dim = Instance.new("Frame")
	dim.Name = name
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = NeonConfig.Palette.Background
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Parent = parent
	return dim
end

-- A thin neon bar (health, boss health, combo timer).
function NeonGui.newBar(name: string, parent: Instance, fillColor: Color3): (Frame, Frame)
	local back = Instance.new("Frame")
	back.Name = name .. "Back"
	back.BackgroundColor3 = NeonConfig.Palette.Background
	back.BackgroundTransparency = 0.25
	back.BorderSizePixel = 0
	back.Parent = parent
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 6)
	backCorner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = fillColor
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill
	return back, fill
end

return NeonGui
