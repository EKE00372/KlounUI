local addon, ns = ...
local C, F, G, L = unpack(ns)
local M = F.RegisterModule("BetterRaid", "BetterRaid")
local Ambiguate = Ambiguate

function M:OnEnable()
	-------------------
	-- 移除伺服器後綴 --
	-------------------

	local function RemoveRealmName(frame)
		-- 防止污染
		if frame:IsForbidden() or not frame.name then return end
		-- 標記給後續的暴雪更新流程使用
		frame.hideRealmName = true
		-- 跳過沒名字的框體
		if not frame.name:IsShown() then return end
		-- 處理當前已經寫進 FontString 的文字
		local name = frame.name:GetText()
		local shortName = name and (Ambiguate and Ambiguate(name, "short") or name:gsub("%-[^-]+$", ""))
		if shortName and shortName ~= name then
			frame.name:SetText(shortName)
		end
	end

	if CompactUnitFrame_UpdateName then
		hooksecurefunc("CompactUnitFrame_UpdateName", RemoveRealmName)
	end

	-----------------
	-- 移除隊伍標題 --
	-----------------

	local function HideGroupTitle(frame)
		if frame and frame.title then
			frame.title:Hide()
		end
	end
	
	-- 團隊的小隊標題
	if CompactRaidGroup_InitializeForGroup then
		hooksecurefunc("CompactRaidGroup_InitializeForGroup", HideGroupTitle)
	end

	-- 團隊風格隊伍框架的標題
	if CompactPartyFrame_OnLoad then
		hooksecurefunc("CompactPartyFrame_OnLoad", HideGroupTitle)
	elseif CompactPartyFrameMixin and CompactPartyFrameMixin.OnLoad then
		hooksecurefunc(CompactPartyFrameMixin, "OnLoad", HideGroupTitle)
	end
end
