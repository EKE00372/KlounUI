----------------------
-- Dont touch this! --
----------------------

local addon, ns = ...
	ns[1] = {} -- C, config
	ns[2] = {} -- F, functions, constants, variables
	ns[3] = {} -- G, globals (Optionnal)
	ns[4] = {} -- L, localization
		
local C, F, G, L = unpack(ns)

local MediaFolder = "Interface\\AddOns\\!Anyon\\Media\\"
local FontFolder = MediaFolder.."Font\\"
local SoundFolder = MediaFolder.."Sound\\"
local TextureFolder = MediaFolder.."Texture\\"

----------------------
-- Golbal and Media --
----------------------

	G.Ccolors = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[select(2, UnitClass("player"))]
	
	G.BarTex = "Interface\\Buttons\\WHITE8X8"
	G.GlowTex = TextureFolder.."glow.tga"
	G.Resize = TextureFolder.."Resize.tga"
	
	G.Mail = "Interface\\MINIMAP\\TRACKING\\Mailbox.blp"  -- "Interface\\HELPFRAME\\ReportLagIcon-Mail.blp"
	G.Diff = TextureFolder.."difficulty.tga"
	G.Report = "Interface\\HelpFrame\\HelpIcon-ReportLag.blp"
	
	G.HealthWarning = SoundFolder.."HealthWarning.ogg" 
	G.ManaWarning = SoundFolder.."ManaWarning.ogg" 
	G.TauntBeep = SoundFolder.."TauntBeep.ogg" -- https://freesound.org/people/pan14/sounds/263128/
	
	G.SpotMe = TextureFolder.."NeonReticule-blue.tga"
	
	G.Font = STANDARD_TEXT_FONT
	G.CTCFont = FontFolder.."Myriad Pro Semibold Condensed.ttf"
	G.FontSize = 14
	G.FontFlag = "OUTLINE"

--------------
-- Settings --
--------------

	C.defaultSettings = {

		["UIScale"] = true,
		["idTip_Opt1"] = true,
		["idTip_Opt2"] = false,
		["idTip_Opt3"] = false,
		["tullaCTC"] = false,
		["tullaRange"] = false,
		["MicroMenu"] = true,
		["BetterRaid"] = false,
		["HideTutorial"] = true,
		["TalkingHeadMode"] = 1,

		["AutoInvite"] = false,
		["AutoLog"] = true,
		["AutoShot"] = true,
		["SnowfallCursor"] = true,
	}

----------
-- Init --
----------

	local pairs, ipairs, next, type = pairs, ipairs, next, type
	local xpcall, geterrorhandler = xpcall, geterrorhandler
	local tinsert, wipe = table.insert, wipe
	local settingsReady = false
	local settingsCallbacks = {}
	local modulesReady = false
	local modules = {}
	local moduleQueue = {}

	local function SafeCall(callback, ...)
		-- 讓初始化與事件回呼都走 Blizzard 錯誤處理器；單一模組報錯不會中斷整串載入。
		return xpcall(callback, geterrorhandler(), ...)
	end

------------
-- Events --
------------

	local eventCallbacks = {}
	local eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", function(_, event, ...)
		local callbacks = eventCallbacks[event]
		if not callbacks then return end

		for callback in pairs(callbacks) do
			SafeCall(callback, event, ...)
		end
	end)

	-- 輕量事件分派器 credits: NDui
	F.RegisterEvent = function(event, callback, unit1, unit2)
		if type(event) ~= "string" or type(callback) ~= "function" then return end

		if not eventCallbacks[event] then
			eventCallbacks[event] = {}
			if unit1 then
				eventFrame:RegisterUnitEvent(event, unit1, unit2)
			else
				eventFrame:RegisterEvent(event)
			end
		end

		eventCallbacks[event][callback] = true
	end

	F.UnregisterEvent = function(event, callback)
		if type(event) ~= "string" or type(callback) ~= "function" then return end

		local callbacks = eventCallbacks[event]
		if callbacks then
			callbacks[callback] = nil
			if not next(callbacks) then
				eventCallbacks[event] = nil
				eventFrame:UnregisterEvent(event)
			end
		end
	end

	-- SavedVariables 尚未初始化前，C.xxx 先使用預設值；真正的 AnyonDB 會在 ADDON_LOADED 後同步。
	for key, value in pairs(C.defaultSettings) do
		C[key] = value
	end

	local function GetDB()
		-- TOC 的 ## SavedVariables: AnyonDB 宣告設定值存在 AnyonDB[key]。
		-- 首次載入或 SavedVariables 損壞時補成空表，之後所有設定讀寫都走同一張表。
		if type(AnyonDB) ~= "table" then
			AnyonDB = {}
		end

		return AnyonDB
	end

	local function NormalizeSettingValue(key, value)
		-- 目前設定值都是 boolean；型別不符時套用 Init.lua 的預設值。
		local defaultValue = C.defaultSettings[key]
		if type(defaultValue) == "boolean" then
			if type(value) ~= "boolean" then
				return defaultValue
			end
			return value
		end

		return value ~= nil and value or defaultValue
	end

	local function SyncSettingValue(key)
		-- C.xxx 是功能檔載入時使用的執行期快取；來源仍然是 AnyonDB。
		local settings = GetDB()
		settings[key] = NormalizeSettingValue(key, settings[key])
		C[key] = settings[key]
		return C[key]
	end

	F.GetDB = GetDB
	F.NormalizeSettingValue = NormalizeSettingValue
	F.SyncSettingValue = SyncSettingValue

	F.GetDefaultSetting = function(key)
		return NormalizeSettingValue(key, C.defaultSettings[key])
	end

	F.GetSetting = function(key)
		if C.defaultSettings[key] == nil then return nil end
		if not settingsReady then return C[key] end

		return SyncSettingValue(key)
	end

	F.SetSetting = function(key, value)
		if C.defaultSettings[key] == nil then return nil end
		if not settingsReady then
			C[key] = NormalizeSettingValue(key, value)
			return C[key]
		end

		local settings = GetDB()
		settings[key] = NormalizeSettingValue(key, value)
		C[key] = settings[key]
		return C[key]
	end

	F.InitializeSettings = function()
		local settings = GetDB()

		-- 刪除設定檔中已不在預設列表內的冗餘設定值。
		for key in pairs(settings) do
			if C.defaultSettings[key] == nil then
				settings[key] = nil
			end
		end

		-- 從預設列表補齊缺少的設定
		for key in pairs(C.defaultSettings) do
			SyncSettingValue(key)
		end
	end

	F.AreSettingsReady = function()
		return settingsReady
	end

	F.RunWhenSettingsReady = function(callback)
		-- 非模組初始化用：例如 GUI 需要等 AnyonDB 同步後才建立設定面板。
		if type(callback) ~= "function" then return end
		if settingsReady then
			SafeCall(callback)
		else
			tinsert(settingsCallbacks, callback)
		end
	end

	local function RunSettingsCallbacks()
		for _, callback in ipairs(settingsCallbacks) do
			SafeCall(callback)
		end
		wipe(settingsCallbacks)
	end

	-------------
	-- Modules --
	-------------

	local function IsModuleSettingEnabled(settingKey)
		-- settingKey 可為單一 key、多個 key，或自訂函數。
		-- 多個 key 使用「任一啟用就載入」，適合 idTip 這種下拉多選模組。
		if not settingKey then return true end

		if type(settingKey) == "function" then
			return settingKey()
		elseif type(settingKey) == "table" then
			for _, key in ipairs(settingKey) do
				if F.GetSetting(key) then
					return true
				end
			end
			return false
		end

		return F.GetSetting(settingKey)
	end

	local function EnableModule(module)
		if module.enabled or not IsModuleSettingEnabled(module.settingKey) then return end
		module.enabled = true

		if module.OnEnable then
			SafeCall(module.OnEnable, module)
		end
	end

	local function EnableModules()
		modulesReady = true

		for _, module in ipairs(moduleQueue) do
			EnableModule(module)
		end
	end

	F.RegisterModule = function(name, settingKey)
		-- 功能檔只負責登記自己；Init.lua 會在 PLAYER_LOGIN 時依 AnyonDB 設定決定是否啟用。
		if type(name) ~= "string" or name == "" then return end
		if modules[name] then return modules[name] end

		local module = {
			name = name,
			settingKey = settingKey,
		}

		modules[name] = module
		tinsert(moduleQueue, module)

		-- 若未來出現 PLAYER_LOGIN 後才登記的檔案，等目前 Lua 檔跑完再啟用。
		-- 這樣 local M = F.RegisterModule(...); function M:OnEnable() ... end 的 OnEnable 會先定義完成。
		if modulesReady then
			if C_Timer and C_Timer.After then
				C_Timer.After(0, function()
					EnableModule(module)
				end)
			else
				EnableModule(module)
			end
		end

		return module
	end

	F.GetModule = function(name)
		return modules[name]
	end

	F.GetModules = function()
		return modules
	end

	local function OnAddonLoaded(event, loadedAddon)
		if loadedAddon ~= addon then return end

		F.InitializeSettings()
		settingsReady = true
		RunSettingsCallbacks()

		F.UnregisterEvent(event, OnAddonLoaded)
	end

	local function OnPlayerLogin(event)
		-- SavedVariables 仍在 ADDON_LOADED 同步；模組統一等 PLAYER_LOGIN 後才依設定載入。
		EnableModules()

		F.UnregisterEvent(event, OnPlayerLogin)
	end

	F.RegisterEvent("ADDON_LOADED", OnAddonLoaded)
	F.RegisterEvent("PLAYER_LOGIN", OnPlayerLogin)


---------------
-- Functions --
---------------
	
	-- [[ Multi check ]] --
	-- F.Multicheck(unit, "player", "boss", "pet")
	F.Multicheck = function(check, ...)
		for i = 1, select("#", ...) do
			if check == select(i, ...) then
				return true
			end
		end
		return false
	end
	
	
-------------
-- Credits --
-------------
--[[
	楼上的你妈妈叫你吃饭: http://bbs.nga.cn/read.php?tid=4667432
	AIO: https://github.com/Stanzilla/AdvancedInterfaceOptions
	ELVUI: http://git.tukui.org/Elv/elvui/blob/master/ElvUI/core/install.lua
	MONOUI: https://www.wowinterface.com/downloads/info18071-MonoUI.html

]]--
-----------
-- Notes --
-----------
--[[
	wowpedia
	https://wow.gamepedia.com/CVar_cvar_default
	https://wow.gamepedia.com/API_C_CVar.SetCVar
	https://wow.gamepedia.com/API_ConsoleExec
	https://wow.gamepedia.com/Console_variables
	https://wow.gamepedia.com/Console_variables/Complete_list
	https://wow.gamepedia.com/Console_variables/Complete_list/Character
	https://wow.gamepedia.com/Console_variables/Complete_list/Classic
	
	Resetting the WoW User Interface - Blizzard Support
	https://us.battle.net/support/en/article/7549
	
	Mouse jumping/centering FIX
	https://eu.forums.blizzard.com/en/wow/t/mouse-jumping-centering-fix/40704
	
	[代码片段]界面设置自动化
	https://bbs.nga.cn/read.php?tid=15294332
	
	CVAR簡表
	http://bbs.nga.cn/read.php?tid=9622396
]]--
