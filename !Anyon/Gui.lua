local addonName, ns = ...
local C, F = ns[1], ns[2]

local ADDON_TITLE = "!Anyon"

--[[
	選項模板：
	key     = 存檔欄位名稱，同時會同步到 C[key]
	name    = Blizzard Settings 內顯示的名稱
	desc    = 滑鼠提示文字
	default = 預設 true/false

	之後新增實際功能時，只要改這裡的 key/name/desc/default。
	其他 Lua 檔可用 C.EnableOption01 或 F.AnyonGUI.Get("EnableOption01") 讀取設定。
]]--
local OPTIONS = {
	{ key = "EnableOption01", name = "功能 01", desc = "TODO: 填入功能 01 說明。", default = false },
	{ key = "EnableOption02", name = "功能 02", desc = "TODO: 填入功能 02 說明。", default = false },
	{ key = "EnableOption03", name = "功能 03", desc = "TODO: 填入功能 03 說明。", default = false },
	{ key = "EnableOption04", name = "功能 04", desc = "TODO: 填入功能 04 說明。", default = false },
	{ key = "EnableOption05", name = "功能 05", desc = "TODO: 填入功能 05 說明。", default = false },
	{ key = "EnableOption06", name = "功能 06", desc = "TODO: 填入功能 06 說明。", default = false },
	{ key = "EnableOption07", name = "功能 07", desc = "TODO: 填入功能 07 說明。", default = false },
	{ key = "EnableOption08", name = "功能 08", desc = "TODO: 填入功能 08 說明。", default = false },
	{ key = "EnableOption09", name = "功能 09", desc = "TODO: 填入功能 09 說明。", default = false },
	{ key = "EnableOption10", name = "功能 10", desc = "TODO: 填入功能 10 說明。", default = false },
}

local OPTION_BY_KEY = {}

AnyonDB = AnyonDB or {}
AnyonDB.options = AnyonDB.options or {}

local function GetDefaultValue(option)
	return option.default == true
end

local function GetOptionValue(option)
	local value = AnyonDB.options[option.key]
	if type(value) ~= "boolean" then
		value = GetDefaultValue(option)
		AnyonDB.options[option.key] = value
	end

	return value
end

local function SetOptionValue(option, value)
	value = value and true or false

	AnyonDB.options[option.key] = value
	C[option.key] = value
end

for _, option in ipairs(OPTIONS) do
	OPTION_BY_KEY[option.key] = option
	SetOptionValue(option, GetOptionValue(option))
end

local panel = CreateFrame("Frame")
panel.name = ADDON_TITLE

local checkButtons = {}

local function RefreshControls()
	for _, checkButton in ipairs(checkButtons) do
		checkButton:SetChecked(GetOptionValue(checkButton.option))
	end
end

local function ShowTooltip(owner, option)
	if not option.desc or option.desc == "" then
		return
	end

	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(option.name, 1, 1, 1)
	GameTooltip:AddLine(option.desc, nil, nil, nil, true)
	GameTooltip:Show()
end

local function CreateCheckButton(parent, option, index)
	local checkButton = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkButton:SetSize(26, 26)
	checkButton:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, -70 - ((index - 1) * 32))
	checkButton.option = option

	local label = checkButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	label:SetPoint("LEFT", checkButton, "RIGHT", 6, 0)
	label:SetText(option.name)

	checkButton:SetScript("OnClick", function(self)
		SetOptionValue(self.option, self:GetChecked())
	end)

	checkButton:SetScript("OnEnter", function(self)
		ShowTooltip(self, self.option)
	end)

	checkButton:SetScript("OnLeave", GameTooltip_Hide)

	return checkButton
end

local function BuildPanel()
	if panel.initialized then
		RefreshControls()
		return
	end

	panel.initialized = true

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText(ADDON_TITLE)

	local subText = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	subText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	subText:SetText("勾選啟用，取消勾選停用。")

	for index, option in ipairs(OPTIONS) do
		local checkButton = CreateCheckButton(panel, option, index)
		checkButtons[index] = checkButton
	end

	RefreshControls()
end

panel:SetScript("OnShow", BuildPanel)

local categoryID

local function RegisterSettingsPanel()
	if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, ADDON_TITLE)
		category.ID = ADDON_TITLE
		Settings.RegisterAddOnCategory(category)
		categoryID = category.ID
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

local function OpenSettingsPanel()
	if Settings and Settings.OpenToCategory and categoryID then
		Settings.OpenToCategory(categoryID)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

F.AnyonGUI = {
	options = OPTIONS,

	Get = function(key)
		local option = OPTION_BY_KEY[key]
		if option then
			return GetOptionValue(option)
		end
	end,

	Set = function(key, value)
		local option = OPTION_BY_KEY[key]
		if option then
			SetOptionValue(option, value)
			RefreshControls()
		end
	end,

	Open = OpenSettingsPanel,
}

RegisterSettingsPanel()

SlashCmdList["ANYON"] = OpenSettingsPanel
SLASH_ANYON1 = "/anyon"
