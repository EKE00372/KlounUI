local _, ns = ...
local C, F, G = unpack(ns)
local M = F.RegisterModule("AuraFrames", "AuraFrames")

local _G = getfenv(0)
local ipairs, unpack = ipairs, unpack
local CreateFrame, RegisterStateDriver = CreateFrame, RegisterStateDriver
local UnitHasVehicleUI, UIParent = UnitHasVehicleUI, UIParent

local AURA_CONTAINER_ADDON = "Blizzard_AuraContainer"
local AURA_BORDER_PADDING = 1
local auraContainers = {}
local builtFrames

-- 12.1+ 直接使用 Blizzard_AuraContainer；若 OptionalDeps 還沒先載入，這裡補載一次。
local function LoadAuraContainer()
	if not C_AddOns.IsAddOnLoaded(AURA_CONTAINER_ADDON) then
		C_AddOns.LoadAddOn(AURA_CONTAINER_ADDON)
	end
end

local HiddenFrame = CreateFrame("Frame")
HiddenFrame:Hide()

-- 把不要用的原生框體藏到隱藏框架下面，避免它自己又跑回畫面上。
local function HideObject(frame)
	if not frame then return end

	frame:Hide()
	frame:SetParent(HiddenFrame)

	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
end

-- 關掉暴雪原本右上角 BuffFrame/DebuffFrame，之後由 Anyon 自己建立的光環框架接手。
local function HideBlizzardAuraFrames()
	-- Blizzard_AuraContainer 會接管私有光環與右鍵取消光環；原生 BuffFrame/DebuffFrame 只需要隱藏。
	if _G.BuffFrame then
		HideObject(_G.BuffFrame)
		_G.BuffFrame.numHideableBuffs = 0
	end

	if _G.DebuffFrame then
		HideObject(_G.DebuffFrame)
	end
end

-- 建立並快取倒數時間格式；每顆光環共用同一個 formatter，避免重複建立。
local durationFormatter
local function GetDurationFormatter()
	if durationFormatter then
		return durationFormatter
	end

	local rounding = Enum.NumericRuleFormatRounding.Up

	-- 只交給 Blizzard duration binding 使用，不直接呼叫 formatter:Format()。
	durationFormatter = C_StringUtil.CreateNumericRuleFormatter()
	durationFormatter:SetBreakpoints({
		{
			threshold = 0,
			format = "%dS",
			rounding = rounding,
			step = 1,
		},
		{
			threshold = 60,
			format = "%dM",
			components = { { div = 60, rounding = rounding, step = 1 } },
		},
		{
			threshold = 3600,
			format = "%dH",
			components = { { div = 3600, rounding = rounding, step = 1 } },
		},
		{
			threshold = 86400,
			format = "%dD",
			components = { { div = 86400, rounding = rounding, step = 1 } },
		},
	})

	return durationFormatter
end

-- 統一光環文字的字體、描邊和陰影設定。
local function SetFont(fontString, size)
	if not fontString then return end

	fontString:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
	fontString:SetShadowColor(0, 0, 0, 0)
	fontString:SetWordWrap(false)
end

-- 玩家在載具上時，右上角光環要看 vehicle；平常就看 player。
local function GetUnitToken()
	return UnitHasVehicleUI("player") and "vehicle" or "player"
end

-- 載具狀態改變時，把所有已建立的 AuraContainer 切到目前該看的單位。
local function UpdateContainerUnits()
	local unit = GetUnitToken()

	for _, container in ipairs(auraContainers) do
		container:SetUnit(unit)
	end
end

-- 算一整行光環實際佔用的寬度，給 AuraContainer 排版用。
local function GetRowWidth(cfg)
	return (cfg.size * cfg.wrapAfter) + (C.Auras.Margin * (cfg.wrapAfter - 1))
end

-- holder 是外層定位用框架；這裡算它需要多寬。
local function GetHolderWidth(cfg)
	return (cfg.size + C.Auras.Margin) * cfg.wrapAfter
end

-- holder 是外層定位用框架；這裡算它需要多高。
local function GetHolderHeight(cfg)
	return (cfg.size + cfg.offset) * cfg.maxWraps
end

-- 無類型 debuff 沒有 dispelName，不會觸發 Blizzard 自動染色；這裡手動給它預設紅色。
local function SetDefaultDebuffBorderColor(texture)
	local color = AuraUtil and AuraUtil.GetAuraBorderColor and AuraUtil.GetAuraBorderColor()
	if color and color.GetRGBA then
		texture:SetVertexColor(color:GetRGBA())
	else
		texture:SetVertexColor(.8, 0, 0, 1)
	end
end

local function AddDispelBorder(button, texture)
	if button.AddDispelTypeTexture then
		button:AddDispelTypeTexture(texture, {
			showWhenHelpful = false,
			showWhenHarmful = true,
			style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
		})
	else
		button:SetAuraBorder(texture, {
			showIcon = false,
			showWhenHelpful = false,
			showWhenHarmful = true,
			style = AuraButtonBorderStyle.Color,
		})
	end
end

local function SetDurationText(button, fontString)
	if button.AddDispelTypeTexture then
		local binding = C_DurationUtil.CreateDurationTextBinding()
		binding:SetFormatter(GetDurationFormatter())
		binding:SetExpiredText("")
		binding:SetZeroDurationText("")

		button:SetDurationText(fontString, {
			binding = binding,
		})
	else
		button:SetDurationText(fontString, {
			formatter = GetDurationFormatter(),
			expiredText = "",
			zeroDurationText = "",
		})
	end
end

-- 回傳每顆光環按鈕的初始化函數；AuraContainer 建立新按鈕時會呼叫它。
local function CreateAuraButtonInitializer(cfg, canCancelAura, showDefaultDebuffBorder)
	return function(button)
		local size = cfg.size
		local fullHeight = cfg.size + cfg.offset

		button:SetSize(size, fullHeight)

		-- 保留 Blizzard AuraButton 的互動行為；這個子框架只負責圖示外觀。
		local iconFrame = CreateFrame("Frame", nil, button, "BackdropTemplate")
		iconFrame:SetSize(size, size)
		iconFrame:SetPoint("TOP", button, "TOP")
		button.IconFrame = iconFrame

		if showDefaultDebuffBorder then
			-- 無類型 debuff 沒有 dispelName，Blizzard 不會自動顯示 AuraBorder；這層固定顯示自訂紅框。
			local defaultBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil, 0)
			defaultBorder:SetTexture(G.BorderTex)
			defaultBorder:SetPoint("TOPLEFT", iconFrame, -AURA_BORDER_PADDING, AURA_BORDER_PADDING)
			defaultBorder:SetPoint("BOTTOMRIGHT", iconFrame, AURA_BORDER_PADDING, -AURA_BORDER_PADDING)
			SetDefaultDebuffBorderColor(defaultBorder)
		end

		local dispelBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
		dispelBorder:SetTexture(G.BorderTex)
		dispelBorder:SetPoint("TOPLEFT", iconFrame, -AURA_BORDER_PADDING, AURA_BORDER_PADDING)
		dispelBorder:SetPoint("BOTTOMRIGHT", iconFrame, AURA_BORDER_PADDING, -AURA_BORDER_PADDING)
		dispelBorder:Hide()
		AddDispelBorder(button, dispelBorder)

		local icon = iconFrame:CreateTexture(nil, "ARTWORK")
		icon:SetPoint("TOPLEFT", iconFrame, 1, -1)
		icon:SetPoint("BOTTOMRIGHT", iconFrame, -1, 1)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		button:SetIcon(icon)

		local count = iconFrame:CreateFontString(nil, "OVERLAY")
		count:SetDrawLayer("OVERLAY", 3)
		count:SetPoint("BOTTOMRIGHT", iconFrame, 1, -5)
		count:SetTextColor(1, 1, 0)
		SetFont(count, C.Auras.CountFontSize)
		button:SetApplicationCount(count)

		local duration = button:CreateFontString(nil, "OVERLAY")
		duration:SetPoint("TOP", iconFrame, "BOTTOM", 1, 2)
		SetFont(duration, C.Auras.TimerFontSize)
		SetDurationText(button, duration)

		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetColorTexture(1, 1, 1, 0.25)
		highlight:SetAllPoints(iconFrame)

		local border = F.CreateBD(iconFrame, iconFrame, 1, .1, .1, .1, 1)
		local shadow = F.CreateSD(iconFrame, iconFrame, 4)
		border:EnableMouse(false)
		shadow:EnableMouse(false)

		-- 右鍵取消光環仍由 Blizzard AuraButton 內部處理。
		button:SetCancelAuraButtons(canCancelAura and "RightButtonUp" or nil)
	end
end

-- 設定這組光環從哪個角落開始排，還有往左/往右、往下成長。
local function ConfigureAuraContainer(container, cfg)
	local anchorPoint = cfg.reverseGrow and "TOPLEFT" or "TOPRIGHT"
	local horizontalGrowth = cfg.reverseGrow and AnchorUtil.FlowDirection.Right or AnchorUtil.FlowDirection.Left

	if container.SetFlowLayoutAnchorPoint then
		container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
		container:SetFlowLayoutAnchorPoint(anchorPoint)
		container:SetFlowLayoutGrowthDirection(horizontalGrowth, AnchorUtil.FlowDirection.Down)
		container:SetFlowLayoutPadding(0, 0, 0, 0)
		container:SetFlowLayoutMaximumLineSize(GetRowWidth(cfg))
	else
		container:SetAuraLayoutAnchorPoint(anchorPoint)
		container:SetAuraLayoutGrowthDirection(horizontalGrowth, AnchorUtil.FlowDirection.Down)
		container:SetAuraLayoutPadding(0, 0, 0, 0)
		container:SetAuraLayoutRowWidth(GetRowWidth(cfg))
	end

	-- 不覆寫 ShouldIncludePrivateAuraSource；12.1 的 AuraContainer 自己處理私有光環權限。
end

local function GetLayoutOptions(container, cfg)
	if container.SetFlowLayoutAnchorPoint then
		return {
			elementSpacing = C.Auras.Margin,
			lineSpacing = 0,
			groupSpacing = 0,
			groupLineSpacing = 0,
			elementWidth = cfg.size,
			elementHeight = cfg.size + cfg.offset,
		}
	else
		return {
			elementSpacingX = C.Auras.Margin,
			elementSpacingY = 0,
			elementWidth = cfg.size,
			elementHeight = cfg.size + cfg.offset,
		}
	end
end

-- 加入一組光環資料，例如 Buffs 或 Debuffs，並指定每顆按鈕怎麼建立、怎麼排列。
local function AddAuraGroup(container, key, filter, cfg, canCancelAura)
	container:AddAuraGroup(key, filter, {
		maxFrameCount = cfg.wrapAfter * cfg.maxWraps,
		initializeFrame = CreateAuraButtonInitializer(cfg, canCancelAura, filter == "HARMFUL"),
		sortMethod = AuraContainerSortMethod.Default,
		sortDirection = AuraContainerSortDirection.Normal,
		layout = GetLayoutOptions(container, cfg),
	})
end

-- 把武器附魔圖示加入 buff 列前面；永久附魔隱藏，只顯示會倒數的臨時附魔。
local function AddItemEnchantments(container, cfg)
	local options = {
		hidePermanent = true,
		initializeFrame = CreateAuraButtonInitializer(cfg, false),
	}

	container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.MainHand, options)
	container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.OffHand, options)
	container:AddItemEnchantment(AuraContainerItemEnchantmentSlot.Ranged, options)
	container:SetItemEnchantmentSortMethod(AuraContainerItemEnchantmentSortMethod.Slot, AuraContainerSortDirection.Normal)

	local layout = GetLayoutOptions(container, cfg)
	layout.placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups
	container:SetItemEnchantmentLayout(layout)
end

-- 建立一個完整光環區塊：外層 holder 負責定位，內層 AuraContainer 負責真正顯示光環。
local function CreateAuraContainer(name, groupKey, filter, cfg, canCancelAura, includeItemEnchantments)
	local holder = CreateFrame("Frame", name, UIParent)
	holder:SetClampedToScreen(true)
	holder:SetSize(GetHolderWidth(cfg), GetHolderHeight(cfg))

	if RegisterStateDriver then
		RegisterStateDriver(holder, "visibility", "[petbattle] hide; show")
	end

	local container = CreateFrame("AuraContainer", name.."Container", holder, "CustomAuraContainerTemplate")
	local anchorPoint = cfg.reverseGrow and "TOPLEFT" or "TOPRIGHT"
	container:SetPoint(anchorPoint, holder, anchorPoint, 0, 0)
	container:SetEnabled(false)
	ConfigureAuraContainer(container, cfg)

	if includeItemEnchantments then
		AddItemEnchantments(container, cfg)
	end

	AddAuraGroup(container, groupKey, filter, cfg, canCancelAura)
	container:SetUnit(GetUnitToken())
	container:SetEnabled(true)

	auraContainers[#auraContainers + 1] = container
	return holder, container
end

-- 只建立一次玩家 buff/debuff 框架。
local function BuildAuraFrames()
	if builtFrames then
		return
	end

	LoadAuraContainer()
	builtFrames = true
	HideBlizzardAuraFrames()

	local buffCfg = {
		offset = 12,
		size = C.Auras.BuffSize,
		wrapAfter = C.Auras.BuffsPerRow,
		maxWraps = 3,
		reverseGrow = C.Auras.ReverseBuff,
	}

	local debuffCfg = {
		offset = 12,
		size = C.Auras.DebuffSize,
		wrapAfter = C.Auras.DebuffsPerRow,
		maxWraps = 2,
		reverseGrow = C.Auras.ReverseDebuff,
	}

	local buffs = CreateAuraContainer("AnyonPlayerBuffs", "Buffs", "HELPFUL", buffCfg, true, true)
	buffs:ClearAllPoints()
	buffs:SetPoint(unpack(C.Auras.BuffPos))

	local debuffs = CreateAuraContainer("AnyonPlayerDebuffs", "Debuffs", "HARMFUL", debuffCfg, false, false)
	debuffs:ClearAllPoints()
	debuffs:SetPoint("TOPRIGHT", buffs, "BOTTOMRIGHT", 0, -12)

	UpdateContainerUnits()
end

-- 進入世界或上下載具時，補建框架並更新目前應該顯示 player 還是 vehicle。
local function OnEvent(_, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		-- 進入世界後再壓一次原生框體，避免暴雪框架自己重新顯示。
		BuildAuraFrames()
		if builtFrames then
			HideBlizzardAuraFrames()
			UpdateContainerUnits()
		end
	elseif unit == "player" and builtFrames then
		UpdateContainerUnits()
	end
end

-- Anyon 模組啟用點；設定打開時才真正建立光環框架並掛後續事件。
function M:OnEnable()
	-- 模組由 Init.lua 統一在 PLAYER_LOGIN 後啟用；這裡才依設定真正建立光環框架。
	BuildAuraFrames()

	local loader = CreateFrame("Frame")
	loader:RegisterEvent("PLAYER_ENTERING_WORLD")
	loader:RegisterEvent("UNIT_ENTERED_VEHICLE")
	loader:RegisterEvent("UNIT_EXITED_VEHICLE")
	loader:SetScript("OnEvent", OnEvent)
end
