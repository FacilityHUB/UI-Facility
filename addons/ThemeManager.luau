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

	function ThemeManager:BuildThemeSection(tab, column)
		local section = tab:Section("theme", column or 1)

		local picker
		local preset = section:Dropdown({
			Text = "preset",
			Flag = "theme_preset",
			Options = self:Names(),
			Default = self.Current,
			Callback = function(name)
				if self:Apply(name) and picker then
					picker:Set(Theme.Accent, nil, true)
				end
			end,
		})

		picker = section:ColorPicker({
			Text = "accent",
			Flag = "theme_accent",
			Alpha = false,
			Default = Theme.Accent,
			Callback = function(color)
				self:SetAccent(color)
			end,
		})

		section:Button({
			Text = "reset theme",
			Callback = function()
				self:Apply("rose")
				preset:Set("rose", true)
				picker:Set(Theme.Accent, nil, true)
			end,
		})

		self.Section = section
		return section
	end

	return ThemeManager
end
