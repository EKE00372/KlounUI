local addon, ns = ...
local C, F, G, L = unpack(ns)
local M = F.RegisterModule("BetterRaid", "BetterRaid")

function M:OnEnable()
	-- Init.lua 會在 AnyonDB 同步後依 BetterRaid 設定呼叫這裡。

	local Ambiguate = Ambiguate

	local function IsCompactGroupUnit(unit)
		return unit == "player" or (type(unit) == "string" and (unit:match("^party%d+$") or unit:match("^raid%d+$")))
	end

	local function RemoveRealmName(frame)
		if frame:IsForbidden() or not frame.name or not IsCompactGroupUnit(frame.unit) then return end

		-- 12.1 的 CompactUnitFrame_UpdateName 已支援 frame.hideRealmName。
		-- 先標記給暴雪流程使用，再只處理當前已經寫進 FontString 的文字。
		frame.hideRealmName = true

		if not frame.name:IsShown() then return end

		local name = frame.name:GetText()
		local shortName = name and (Ambiguate and Ambiguate(name, "short") or name:gsub("%-[^-]+$", ""))
		if shortName and shortName ~= name then
			frame.name:SetText(shortName)
		end
	end

	local function HideGroupTitle(frame)
		if frame and frame.title then
			frame.title:Hide()
		end
	end

	-- 隱藏玩家名稱中的伺服器後綴，例如 Name-Realm -> Name。
	if CompactUnitFrame_UpdateName then
		hooksecurefunc("CompactUnitFrame_UpdateName", RemoveRealmName)
	end

	-- 隱藏團隊分組標題，例如 Group 1 / 第 1 隊。
	if CompactRaidGroup_InitializeForGroup then
		hooksecurefunc("CompactRaidGroup_InitializeForGroup", HideGroupTitle)
	end

	-- 隱藏團隊樣式小隊框架上方的 PARTY 標題。
	if CompactPartyFrame_OnLoad then
		hooksecurefunc("CompactPartyFrame_OnLoad", HideGroupTitle)
	elseif CompactPartyFrameMixin and CompactPartyFrameMixin.OnLoad then
		hooksecurefunc(CompactPartyFrameMixin, "OnLoad", HideGroupTitle)
	end
end
