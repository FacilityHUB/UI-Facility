-- Facility addon | ThemeManager
-- Edition des couleurs de l interface, recoloration a chaud.

return function(Library)
	local HttpService = game:GetService("HttpService")
	local Theme = Library.Theme

	local ThemeManager = {}
	ThemeManager.Library = Library
	ThemeManager.Folder = "Facility"
	ThemeManager.Flags = { "theme_preset", "theme_accent" }
	ThemeManager.AutoSave = false

	local function shift(color, saturation, value)
		local h, s, v = color:ToHSV()
		return Color3.fromHSV(h, math.clamp(s * saturation, 0, 1), math.clamp(v * value, 0, 1))
	end

	local function toHex(color, alpha)
		return string.format("#%02X%02X%02X%02X",
			math.floor(color.R * 255 + 0.5),
			math.floor(color.G * 255 + 0.5),
			math.floor(color.B * 255 + 0.5),
			math.floor(math.clamp(alpha or 1, 0, 1) * 255 + 0.5))
	end

	local function fromHex(text)
		if typeof(text) == "Color3" then return text, 1 end
		if type(text) ~= "string" then return nil end
		local hex = string.gsub(string.gsub(text, "#", ""), "%s", "")
		if #hex < 6 then return nil end
		local r = tonumber(string.sub(hex, 1, 2), 16)
		local g = tonumber(string.sub(hex, 3, 4), 16)
		local b = tonumber(string.sub(hex, 5, 6), 16)
		if not r or not g or not b then return nil end
		local a = 255
		if #hex >= 8 then a = tonumber(string.sub(hex, 7, 8), 16) or 255 end
		return Color3.fromRGB(r, g, b), a / 255
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

	function ThemeManager:SetAccent(color)
		color = fromHex(color)
		if not color then return false end
		Theme.Accent = color
		Theme.AccentSoft = shift(color, 0.78, 1.08)
		Theme.AccentDim = shift(color, 0.72, 0.64)
		self.Library:Repaint()
		if self.AutoSave then self:Save() end
		return true
	end

	function ThemeManager:Save()
		local alphas = self.Library.ThemeAlpha or {}
		local colors = {}
		for _, entry in ipairs(self.Keys) do
			colors[entry[1]] = toHex(Theme[entry[1]], alphas[entry[1]])
		end
		local ok, encoded = pcall(function()
			return HttpService:JSONEncode({ Colors = colors })
		end)
		if ok then self.Library.FileSystem:Write(self:Path(), encoded) end
		return ok
	end

	function ThemeManager:Load()
		local raw = self.Library.FileSystem:Read(self:Path())
		if not raw then return false end
		local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if not ok or type(data) ~= "table" then return false end
		for key, hex in pairs(data.Colors or {}) do
			local color, alpha = fromHex(hex)
			if color and Theme[key] ~= nil then
				self.Library:SetColor(key, color, alpha)
			end
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

		local alphas = self.Library.ThemeAlpha or {}
		local defaults = {}
		for _, entry in ipairs(self.Keys) do
			defaults[entry[1]] = Theme[entry[1]]
		end

		local modal = window:Modal({ Title = "theme", Width = 300, Height = 0.82 })
		local content = modal.Content
		local pickers = {}

		local function syncPickers()
			for key, picker in pairs(pickers) do
				picker:Set(Theme[key], alphas[key] or 1, true)
			end
		end

		content:Divider()

		for _, entry in ipairs(self.Keys) do
			local key, label = entry[1], entry[2]
			pickers[key] = content:ColorPicker({
				Text = label,
				Flag = false,
				Default = Theme[key],
				DefaultAlpha = alphas[key] or 1,
				Callback = function(color, alpha)
					self.Library:SetColor(key, color, alpha)
					if key == "Accent" then
						self:SetAccent(color)
						syncPickers()
					elseif self.AutoSave then
						self:Save()
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
					alphas[key] = 1
				end
				self.Library:Repaint()
				syncPickers()
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
