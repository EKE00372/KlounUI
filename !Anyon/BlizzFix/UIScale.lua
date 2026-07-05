local addon, ns = ... 
local C, F, G, L = unpack(ns)

if not C.SetUIScale then return end
--=================================================--
-----------------    [[ Scale ]]    -----------------
--=================================================--

-- [[ Set UI scale ]] --
-- https://www.wowinterface.com/forums/showthread.php?p=328597

local ceil = math.ceil
local SetCVar = C_CVar.SetCVar

local frame

local pendingScale = false
local function SetUIScale()
	-- 戰鬥中延遲載入
	if InCombatLockdown() then
		pendingScale = true
		frame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	pendingScale = false
	frame:UnregisterEvent("PLAYER_REGEN_ENABLED")

	-- 取整
	local _, height = GetPhysicalScreenSize()
	local Scale = ceil((768/height) * 10000 + 0.5) / 10000

	-- 縮放
	SetCVar("useUiScale", "1")
	if Scale >=1 then
		-- 大於1就固定1
		SetCVar("uiScale", 1)
	elseif Scale >= 0.65 then
		-- 使用 cvar 的區間
		SetCVar("uiScale", Scale)
	elseif Scale > 0.5 then
		-- 使用 UIParent 的區間： 小於0.65且大於0.5
		SetCVar("uiScale", 1)
		UIParent:SetScale(Scale)
	else
		-- 超高解析度：二倍縮放
		SetCVar("uiScale", Scale*2)
	end
end

local isScaling = false
local function UpdatePixelScale(self, event)
	-- 防止無限循環
	if isScaling then return end

	if event == "PLAYER_REGEN_ENABLED" and not pendingScale then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	
	isScaling = true
	SetUIScale()
	isScaling = false
end

frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("UI_SCALE_CHANGED")
	--frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
	frame:SetScript("OnEvent", UpdatePixelScale)
