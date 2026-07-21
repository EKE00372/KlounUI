local addon, ns = ...
local C, F, G, L = unpack(ns)

local Ambiguate = Ambiguate
local CinematicFrame = CinematicFrame
local DELETE_ITEM_CONFIRM_STRING = DELETE_ITEM_CONFIRM_STRING

-- [[ Hide talent alerts ]]--

do
	function MainMenuMicroButton_AreAlertsEffectivelyEnabled()
		return false
	end
end

-- [[ Bypass the buggy cancel cinematic confirmation dialog ]] --

do
	if CinematicFrame and CinematicFrame.closeDialog then
		hooksecurefunc(CinematicFrame.closeDialog, "Show", function()
			CinematicFrame.closeDialog:Hide()
			CinematicFrame_CancelCinematic()
		end)
	end
end

-- [[ Auto type delete ]] --

do
	local function FillDeleteConfirmText(dialog)
		-- 12.1 StaticPopup 使用 GameDialogMixin，輸入框要透過 GetEditBox() 取得。
		local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox
		if not editBox or not DELETE_ITEM_CONFIRM_STRING then return end

		editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
		if StaticPopup_StandardConfirmationTextHandler then
			StaticPopup_StandardConfirmationTextHandler(editBox, DELETE_ITEM_CONFIRM_STRING)
		end
	end

	local function HookDeleteDialog(dialogKey)
		local dialog = StaticPopupDialogs and StaticPopupDialogs[dialogKey]
		if not dialog or not dialog.OnShow or dialog.AnyonHookedAutoTypeDelete then return end

		hooksecurefunc(dialog, "OnShow", FillDeleteConfirmText)
		dialog.AnyonHookedAutoTypeDelete = true
	end

	HookDeleteDialog("DELETE_GOOD_ITEM")
	HookDeleteDialog("DELETE_GOOD_QUEST_ITEM")
end

-- [[ Fix action bar row order ]] --

do
	local ipairs = ipairs
	local ceil = math.ceil
	local max = math.max
	local min = math.min
	local tinsert = table.insert
	local wipe = table.wipe

	local AnchorUtil = AnchorUtil
	local CreateFrame = CreateFrame
	local GridLayoutUtil = GridLayoutUtil
	local InCombatLockdown = InCombatLockdown

	local layoutButtons = {}
	local pendingUpdate

	local function ShouldFixRowOrder(bar)
		return bar
			and bar.isNormalBar
			and bar.isHorizontal
			and bar.addButtonsToTop
			and bar.numRows
			and bar.numRows > 1
			and bar.shownButtonContainers
			and #bar.shownButtonContainers > 0
	end

	local function ApplyActionBarRowOrder(bar)
		if not ShouldFixRowOrder(bar) then return end

		-- 戰鬥中不改保護框體錨點，離開戰鬥後再補排。
		if InCombatLockdown() then pendingUpdate = true return end

		local containers = bar.shownButtonContainers
		local numButtons = #containers
		local numRows = bar.numRows
		local stride = ceil(numButtons / numRows)
		local rowCount = ceil(numButtons / stride)

		wipe(layoutButtons)

		-- Blizzard 原生是從下排往上排放；這裡把每一排反過來交給 layout。
		-- 只改容器顯示順序，不改技能槽與快捷鍵。
		for row = rowCount, 1, -1 do
			local firstButton = (row - 1) * stride + 1
			local lastButton = min(row * stride, numButtons)

			for i = firstButton, lastButton do
				tinsert(layoutButtons, containers[i])
			end
		end

		local buttonPadding = max(bar.minButtonPadding, bar.buttonPadding)
		local xMultiplier = bar.addButtonsToRight and 1 or -1
		local layout = GridLayoutUtil.CreateStandardGridLayout(stride, buttonPadding, buttonPadding, xMultiplier, 1)
		local anchorPoint = bar.addButtonsToRight and "BOTTOMLEFT" or "BOTTOMRIGHT"

		GridLayoutUtil.ApplyGridLayout(layoutButtons, AnchorUtil.CreateAnchor(anchorPoint, bar, anchorPoint), layout)
		bar:Layout()
		bar:UpdateSpellFlyoutDirection()
	end

	local function ApplyRegisteredActionBars()
		if not EditModeManagerFrame or not EditModeManagerFrame.registeredSystemFrames then return end

		for _, bar in ipairs(EditModeManagerFrame.registeredSystemFrames) do
			ApplyActionBarRowOrder(bar)
		end
	end

	local function SetupActionBarRowOrder()
		if not ActionBarMixin then return end

		hooksecurefunc(ActionBarMixin, "UpdateGridLayout", ApplyActionBarRowOrder)
		ApplyRegisteredActionBars()
	end

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_LOGIN")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	eventFrame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" then
			SetupActionBarRowOrder()
		elseif pendingUpdate then
			pendingUpdate = nil
			ApplyRegisteredActionBars()
		end
	end)
end
