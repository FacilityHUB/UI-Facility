-- Facility addon | ThemeManager
-- Presets de couleurs, accent personnalise, recoloration a chaud.

return function(Library)
	local HttpService = game:GetService("HttpService")
	local Theme = Library.Theme

	local ThemeManager = {}
	ThemeManager.Library = Library
	ThemeManager.Folder = "Facility"
	ThemeManager.Flags = { "theme_preset", "theme_accent" }
	ThemeManager.AutoSave = false
	ThemeManager.Current = "rose"

	ThemeManager.Order = { "rose", "blue", "green", "amber", "violet", "mono" }
	ThemeManager.Presets = {
		rose   = Color3.fromRGB(232, 161, 168),
		blue   = Color3.fromRGB(120, 178, 240),
		green  = Color3.fromRGB(126, 206, 142),
		amber  = Color3.fromRGB(232, 186, 110),
		violet = Color3.fromRGB(178, 154, 240),
		mono   = Color3.fromRGB(196, 196, 204),
	}

	local function shift(color, saturation, value)
		local h, s, v = color:ToHSV()
		return Color3.fromHSV(h, math.clamp(s * saturation, 0, 1), math.clamp(v * value, 0, 1))
	end

	local function toHex(color)
		return string.format("#%02X%02X%02X",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5))
	end

	local function fromHex(text)
		if typeof(text) == "Color3" then return text end
		if type(text) ~= "string" then return nil end
		local hex = string.gsub(string.gsub(text, "#", ""), "%s", "")
		if #hex < 6 then return nil end
		local r = tonumber(string.sub(hex, 1, 2), 16)
		local g = tonumber(string.sub(hex, 3, 4), 16)
		local b = tonumber(string.sub(hex, 5, 6), 16)
		if not r or not g or not b then return nil end
		return Color3.fromRGB(r, g, b)
	end

	function ThemeManager:SetLibrary(lib)
		self.Library = lib or Library
	end

	function ThemeManager:SetFolder(folder)
		self.Folder = folder
		self.Library:BuildFolders(folder)
	end

	function ThemeManager:Path()
		return self.Folder .. "/settings/theme.json"
	end

	function ThemeManager:Names()
		local names = {}
		for i, name in ipairs(self.Order) do names[i] = name end
		return names
	end

	function ThemeManager:SetAccent(color, name)
		color = fromHex(color)
		if not color then return false end
		Theme.Accent = color
		Theme.AccentSoft = shift(color, 0.78, 1.08)
		Theme.AccentDim = shift(color, 0.72, 0.64)
		self.Current = name or "custom"
		self.Library:Repaint()
		if self.AutoSave then self:Save() end
		return true
	end

	function ThemeManager:Apply(name)
		local preset = self.Presets[name]
		if not preset then return false end
		return self:SetAccent(preset, name)
	end

	function ThemeManager:Save()
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode({ Preset = self.Current, Accent = toHex(Theme.Accent) })
		end)
		if ok then self.Library.FileSystem:Write(self:Path(), encoded) end
		return ok
	end

	function ThemeManager:Load()
		local raw = self.Library.FileSystem:Read(self:Path())
		if not raw then return false end
		local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if not ok or type(data) ~= "table" then return false end
		if data.Accent then
			self:SetAccent(data.Accent, data.Preset)
		elseif data.Preset then
			self:Apply(data.Preset)
		end
		return true
	end

	ThemeManager.Keys = {
		{ "Accent", "accent" },
		{ "AccentSoft", "accent hover" },
		{ "AccentDim", "accent dim" },
		{ "Window", "window bg" },
		{ "WindowBorder", "window border" },
		{ "TopBar", "topbar bg" },
		{ "Section", "card bg" },
		{ "SectionBorder", "card border" },
		{ "Group", "group bg" },
		{ "GroupBorder", "group border" },
		{ "Field", "control bg" },
		{ "FieldHover", "control hover" },
		{ "Border", "control border" },
		{ "BorderSoft", "divider" },
		{ "PopupBg", "popup bg" },
		{ "PopupBorder", "popup border" },
		{ "Track", "slider track" },
		{ "Text", "text" },
		{ "TextDim", "text dim" },
		{ "TextBright", "text bright" },
		{ "TextMarked", "text warning" },
		{ "TextCode", "text success" },
		{ "Danger", "text danger" },
	}

	function ThemeManager:Mount(window)
		window = window or self.Library.Windows[1]
		if not window then return nil end

		local defaults = {}
		for _, entry in ipairs(self.Keys) do
			defaults[entry[1]] = Theme[entry[1]]
		end

		local modal = window:Modal({ Title = "theme", Width = 300, Height = 0.82 })
		local content = modal.Content
		local pickers = {}
		local presetBox

		local function syncPickers()
			for key, picker in pairs(pickers) do
				picker:Set(Theme[key], nil, true)
			end
		end

		presetBox = content:Dropdown({
			Text = "preset",
			Flag = "theme_preset",
			Options = self:Names(),
			Default = self.Current,
			Callback = function(name)
				if self:Apply(name) then syncPickers() end
			end,
		})

		content:Divider()

		for _, entry in ipairs(self.Keys) do
			local key, label = entry[1], entry[2]
			pickers[key] = content:ColorPicker({
				Text = label,
				Flag = false,
				Alpha = false,
				Default = Theme[key],
				Callback = function(color)
					Theme[key] = color
					if key == "Accent" then
						self:SetAccent(color)
						syncPickers()
					else
						self.Library:Repaint()
						if self.AutoSave then self:Save() end
					end
				end,
			})
		end

		content:Divider()

		content:Button({
			Text = "reset colors",
			Callback = function()
				for key, color in pairs(defaults) do
					Theme[key] = color
				end
				self.Current = "rose"
				self.Library:Repaint()
				syncPickers()
				if presetBox then presetBox:Set("rose", true) end
			end,
		})

		window:IconAction("paintbrush", function()
			modal:Toggle()
		end)

		self.Modal = modal
		self.Pickers = pickers
		return modal
	end

	return ThemeManager
end
