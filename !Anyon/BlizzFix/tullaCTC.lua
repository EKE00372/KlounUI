--=================================================--
-----------------    [[ Notes ]]    -----------------
--=================================================--

--[[
	tullaCTC Basic

	A featureless, "pure" single-file version of tullaCTC.
	Source: https://github.com/tullamods/tullaCTC
]]--

--===================================================--
-----------------    [[ Configs ]]    -----------------
--===================================================--

local FONT_FACE = STANDARD_TEXT_FONT
local FONT_FLAGS = "OUTLINE"
local FONT_SIZE = 0						-- 0 表示使用 Blizzard 自動字體大小

-- 時間格式切換門檻
local TENTHS_THRESHOLD = 2.5			-- 小於 2.5 秒顯示小數點
local MMSS_THRESHOLD = 100				-- 100 秒起顯示 mm:ss
local MINUTES_THRESHOLD = 300.5			-- 300 秒後顯示兩位數分鐘
local HOURS_THRESHOLD = 3600			-- 60 分鐘起顯示兩位數小時
local DAYS_THRESHOLD = 86400			-- 24 小時起顯示天數
local ROUNDING_MODE = "Nearest"         -- "Nearest","Up","Down"

-- 文字顏色，格式為 RRGGBBAA
local TEXT_COLORS = {
	{ threshold = 5, color = "FF6347FF" },
	{ threshold = 60, color = "FFFF00FF" },
	{ threshold = 3600, color = "FFFFFFFF" },
}
local DEFAULT_TEXT_COLOR = "AAAAAAFF"

--===================================================--
-----------------    [[ Globals ]]    -----------------
--===================================================--

local AddonName = "tullaCTC"
local Addon = _G[AddonName] or {}
_G[AddonName] = Addon	-- 保留全域 API 供其他插件呼叫

local MINUTE = 60
local HOUR = MINUTE * 60
local DAY = HOUR * 24

local active = {}
local textContainers = {}

--===================================================--
-----------------    [[ Utility ]]    -----------------
--===================================================--

-- 外部調用：無額外規則
function Addon:RegisterRule()
	if self.Refresh then
		self:Refresh()
	end
end

-- 顏色
local createColor = setmetatable({}, {
	__mode = "v",
	__call = function(self, hex)
		if type(hex) ~= "string" or (#hex ~= 8 and #hex ~= 6) then
			return nil
		end

		local color = self[hex]
		if not color then
			if #hex == 8 then
				color = CreateColorFromRGBAHexString(hex)
			elseif #hex == 6 then
				color = CreateColorFromHexString(hex)
			end

			self[hex] = color
		end

		return color
	end,
})

--==================================================--
-----------------    [[ Format ]]    -----------------
--==================================================--

local function thresholdComparer(a, b)
	return a.threshold < b.threshold
end

local function getFormatBreakpoints()
	-- 暴雪預設的時間格式
	local roundingMode = Enum.NumericRuleFormatRounding[ROUNDING_MODE]
	if roundingMode == nil then
		roundingMode = Enum.NumericRuleFormatRounding.Nearest
	end

	local points = {}
	if TENTHS_THRESHOLD > 0 then
		tinsert(points, {
			threshold = 0,
			format = "%.1f",
			rounding = roundingMode,
			step = 0.1,
		})

		tinsert(points, {
			threshold = TENTHS_THRESHOLD,
			format = "%d",
			rounding = roundingMode,
			step = 1,
		})
	elseif roundingMode == Enum.NumericRuleFormatRounding.Up then
		tinsert(points, {
			threshold = 0,
			format = "%d",
			rounding = roundingMode,
			step = 1,
		})
	elseif roundingMode == Enum.NumericRuleFormatRounding.Down then
		tinsert(points, {
			threshold = 0,
			format = "",
			rounding = roundingMode,
			step = 1,
		})

		tinsert(points, {
			threshold = 1,
			format = "%d",
			rounding = roundingMode,
			step = 1,
		})
	else
		tinsert(points, {
			threshold = 0,
			format = "",
			rounding = roundingMode,
			step = 1,
		})

		tinsert(points, {
			threshold = 0.5,
			format = "%d",
			rounding = roundingMode,
			step = 1,
		})
	end

	tinsert(points, {
		threshold = MMSS_THRESHOLD,
		format = "%d:%02d",
		rounding = roundingMode,
		step = 1,
		components = { { div = MINUTE }, { mod = MINUTE } },
	})

	tinsert(points, {
		threshold = MINUTES_THRESHOLD,
		format = "%d",
		components = { { div = MINUTE, rounding = roundingMode, step = 1 } },
	})

	local minutesThreshold = points[#points].threshold

	if HOURS_THRESHOLD > minutesThreshold then
		tinsert(points, {
			threshold = HOURS_THRESHOLD,
			format = "%d",
			components = { { div = HOUR, rounding = roundingMode, step = 1 } },
		})
	end

	if DAYS_THRESHOLD > HOURS_THRESHOLD then
		tinsert(points, {
			threshold = DAYS_THRESHOLD,
			format = "%dd",
			components = { { div = DAY, rounding = roundingMode, step = 1 } },
		})
	end

	return points
end

local function getColorBreakpoints()
	-- 把設定中的結束門檻轉成 formatter 使用的起始門檻。
	local points = {}

	if TEXT_COLORS and #TEXT_COLORS > 0 then
		for i = 1, #TEXT_COLORS do
			local entry = TEXT_COLORS[i]

			points[i] = {
				threshold = entry.threshold,
				color = createColor(entry.color),
			}
		end

		points[#points + 1] = {
			threshold = math.huge,
			color = createColor(DEFAULT_TEXT_COLOR),
		}

		table.sort(points, thresholdComparer)

		-- 原版 tullaCTC 的 threshold 是結束點，這裡轉為起始點。
		for i = #points, 2, -1 do
			points[i].threshold = points[i - 1].threshold
		end
		points[1].threshold = 0
	else
		points[1] = {
			threshold = 0,
			color = createColor(DEFAULT_TEXT_COLOR),
		}
	end

	return points
end

-- 合併顏色分段與時間格式分段
local function createBreakpoints(colors, formats)
	local breakpoints = {}
	local i, j = 1, 1
	local state = {}

	while colors[i] or formats[j] do
		local c, f = colors[i], formats[j]
		local threshold

		if c and (not f or c.threshold <= f.threshold) then
			threshold = c.threshold
			state.color = c.color
			i = i + 1
		end

		if f and (not threshold or f.threshold <= threshold) then
			threshold = f.threshold
			state.step = f.step
			state.rounding = f.rounding
			state.min = f.min
			state.max = f.max
			state.format = f.format
			state.components = f.components
			j = j + 1
		end

		tinsert(breakpoints, {
			threshold = threshold,
			step = state.step,
			rounding = state.rounding,
			min = state.min,
			max = state.max,
			format = state.color and state.color:WrapTextInColorCode(state.format) or state.format,
			components = state.components,
		})
	end

	return breakpoints
end

-- 建立格式
local function createFormatter()
	local colors = getColorBreakpoints()
	local formats = getFormatBreakpoints()
	local breakpoints = createBreakpoints(colors, formats)
	local formatter = C_StringUtil.CreateNumericRuleFormatter()

	formatter:SetBreakpoints(breakpoints)

	return formatter
end

--===================================================--
-----------------    [[ Style ]]    ------------------
--===================================================--

local formatter
local font

local function getFormatter()
	if not formatter then
		formatter = createFormatter()
	end
	return formatter
end

-- 套用樣式
local function styleCooldown(cooldown)
	if cooldown.noCooldownCount then return end
	if cooldown.IsForbidden and cooldown:IsForbidden() then return end

	local text = cooldown:GetCountdownFontString()
	if not text then return end

	if not font then
		font = FONT_FACE
	end

	if FONT_SIZE > 0 then
		if not text:SetFont(font, FONT_SIZE, FONT_FLAGS) then
			text:SetFont(STANDARD_TEXT_FONT, FONT_SIZE, FONT_FLAGS)
		end
	else
		cooldown:SetCountdownFont(font)
	end

	text:ClearAllPoints()
	text:SetPoint("TOPLEFT", 1, -1)
	text:SetJustifyH("CENTER")

	text:SetShadowColor(1, 1, 1, 0)
	text:SetShadowOffset(0, 0)

	cooldown:SetCountdownFormatter(getFormatter())
end

--==============================================================--
-----------------    [[ Cooldown Function ]]    -----------------
--==============================================================--

local nextid
do
	local id = 0
	nextid = function()
		id = id + 1
		return id
	end
end

-- 冷卻結束
local function onCooldownStop(cooldown)
	local cooldownID = cooldown.tullaCTC
	if cooldownID then
		active[cooldownID] = nil
	end
end

-- 抬高層級
local function raiseCooldownText(cooldown, cooldownID)
	if InCombatLockdown() then return end

	local parent = cooldown:GetParent()
	if parent and parent.TextOverlayContainer then
		local container = textContainers[cooldownID]
		if not container then
			container = CreateFrame("Frame", nil, cooldown)

			container:SetAllPoints(cooldown)
			container:SetFrameLevel(777)

			local text = cooldown:GetCountdownFontString()
			if text then
				text:SetParent(container)
			end

			textContainers[cooldownID] = container
		end
	end
end

-- 套用本模板
local function onCooldownStart(cooldown)
	if cooldown.noCooldownCount then
		onCooldownStop(cooldown)
		return
	end
	if cooldown.IsForbidden and cooldown:IsForbidden() then return end

	local cooldownID = cooldown.tullaCTC
	if cooldownID == nil then
		cooldownID = nextid()
		cooldown.tullaCTC = cooldownID
		cooldown:HookScript("OnCooldownDone", onCooldownStop)
	end

	raiseCooldownText(cooldown, cooldownID)
	styleCooldown(cooldown)
	active[cooldownID] = cooldown
end

--===================================================--
-----------------    [[ Updates ]]    -----------------
--===================================================--

-- 清空快取並重新套用
function Addon:Refresh()
	formatter = nil
	font = nil

	for _, cooldown in pairs(active) do
		styleCooldown(cooldown)
	end
end

local loaded
local function OnLoad()
	-- 只初始化一次
	if loaded then return end
	loaded = true

	local cooldownIndex = getmetatable(ActionButton1Cooldown).__index

	hooksecurefunc(cooldownIndex, "SetCooldown", onCooldownStart)
	hooksecurefunc(cooldownIndex, "SetCooldownDuration", onCooldownStart)
	hooksecurefunc(cooldownIndex, "SetCooldownFromDurationObject", onCooldownStart)
	hooksecurefunc(cooldownIndex, "SetCooldownFromExpirationTime", onCooldownStart)
	hooksecurefunc(cooldownIndex, "SetCooldownUNIX", onCooldownStart)
	hooksecurefunc(cooldownIndex, "Clear", onCooldownStop)

	hooksecurefunc("CooldownFrame_SetDisplayAsPercentage", function(cooldown)
		if cooldown.noCooldownCount then return end

		cooldown.noCooldownCount = true
		cooldown:SetHideCountdownNumbers(true)
	end)
end

local function OnEvent(self)
	OnLoad()
	self:UnregisterEvent("PLAYER_LOGIN")
end

--===================================================--
-----------------    [[ Scripts ]]    -----------------
--===================================================--

local EventWatcher = CreateFrame("Frame")
EventWatcher:RegisterEvent("PLAYER_LOGIN")
EventWatcher:SetScript("OnEvent", OnEvent)
