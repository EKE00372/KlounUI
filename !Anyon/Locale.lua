local addon, ns = ...
local C, F, G, L = unpack(ns)
local GetLocale = GetLocale

--===================================================--
-----------------    [[ Locales ]]    -----------------
--===================================================--

if GetLocale() == "zhTW" then

    --[[L.SetUI = "載入 CVAR"
    L.SetUI = "導入預設 CVAR"
    L.SetUI = ""
    L.SetUI = ""
    L.SetUI = ""
    L.SetUI = ""
    L.SetUI = ""]]--

    -- interface

    L.UIScale = "介面縮放"
    L.UIScale_Desc = "自動套用符合解析度的介面縮放比例。\n\n當前解析度的最適縮放比例：%s%%"

    L.idTip = "各種 ID"
    L.idTip_Desc = "替滑鼠提示加上各種 ID。\n\n代碼引用：https://www.curseforge.com/wow/addons/idtip"
    L.idTip_Opt1 = "主要 ID"
    L.idTip_Opt1Desc = "SpellID, ItemID, NPC ID, QuestID, AchievementID, CurrencyID, MacroID, MountID, IconID"
    L.idTip_Opt2 = "其他 ID"
    L.idTip_Opt2Desc = "TalentID, CriteriaID, AbilityID, ArtifactPowerID, EnchantID, GemID, CompanionID, SetID, VisualID, SourceID, SpeciesID, AreaPoiID, VignetteID, ExpansionID, ObjectID"
    L.idTip_Opt3 = "次要 ID"
    L.idTip_Opt3Desc = "BonusID, TraitNodeID, TraitEntryID, TraitDefinitionID"

    L.tullaCTC = "倒數計時"
    L.tullaCTC_Desc = "冷卻和光環的倒數計時文字。\n\n代碼引用：https://www.curseforge.com/wow/addons/tullactc"

    L.tullaRange = "快捷鍵染色"
    L.tullaRange_Desc = "根據距離和資源染色快捷鍵按鈕。\n\n代碼引用：https://www.curseforge.com/wow/addons/tullarange"

    L.HideTutorial = "隱藏教學提示"
    L.HideTutorial_Desc = "隱藏新角色的教學提示。\n\n代碼引用：https://www.curseforge.com/wow/addons/hidetutorial"

    -- misc

    L.AutoInvite = "自動邀請"
    L.AutoInvite_Desc = "密語 111 +++ 自動邀請組隊"

    L.AutoLog = "自動戰鬥紀錄"
    L.AutoLog_Desc = "在團隊副本和傳奇地城自動啟用戰鬥紀錄"

    L.AutoShot = "自動截圖"
    L.AutoShot_Desc = "等級提升、獲得成就、完成限時地城和死亡時自動截圖。"

    L.SnowfallCursor = "游標閃光"
    L.SnowfallCursor_Desc = "滑鼠游標閃光\n\n代碼引用：https://www.wowinterface.com/downloads/info15693-SnowfallCursor.html"

    L.ReloadUI = "重載介面"
    L.ReloadUI_Desc = "重載介面以套用設定。"

else
 -- interface

    L.UIScale = "UI Scale"
    L.UIScale_Desc = "Auto UI Scale for pixel perfect.\nCurrent best scale: %s%%"

    L.idTip = "IDs"
    L.idTip_Desc = "Show IDs on tooltip, Source: https://www.curseforge.com/wow/addons/idtip"
    L.idTip_Opt1 = "Main ID"
    L.idTip_Opt1Desc = "SpellID, ItemID, NPC ID, QuestID, AchievementID, CurrencyID, MacroID, MountID, IconID"
    L.idTip_Opt2 = "Other ID"
    L.idTip_Opt2Desc = "TalentID, CriteriaID, AbilityID, ArtifactPowerID, EnchantID, GemID, CompanionID, SetID, VisualID, SourceID, SpeciesID, AreaPoiID, VignetteID, ExpansionID, ObjectID"
    L.idTip_Opt3 = "Minor ID"
    L.idTip_Opt3Desc = "BonusID, TraitNodeID, TraitEntryID, TraitDefinitionID"

    L.tullaCTC = "Cooldown Text"
    L.tullaCTC_Desc = "Actionbar cooldown and aura time text, Source: https://www.curseforge.com/wow/addons/tullactc"

    L.tullaRange = "Colored actionbar"
    L.tullaRange_Desc = "Actionbar button color by range and resource, Source: https://www.curseforge.com/wow/addons/tullarange"

    L.HideTutorial = "Hide tutorial"
    L.HideTutorial_Desc = "Hide new character tutorial, Source: https://www.curseforge.com/wow/addons/hidetutorial"

    -- misc

    L.AutoInvite = "Auto Invite"
    L.AutoInvite_Desc = "Msg 111 +++ auto invite"

    L.AutoLog = "Auto combatlog"
    L.AutoLog_Desc = "Automatically enable combatlog in Raid and Mythic+ Dungeon."

    L.AutoShot = "Auto screenshot"
    L.AutoShot_Desc = "Automatically tack screenshot when you get achievement, level up, finish a dungeon and death."

    L.SnowfallCursor = "Cursor flash"
    L.SnowfallCursor_Desc = "Cursor flash when moving, Source: https://www.wowinterface.com/downloads/info15693-SnowfallCursor.html"

    L.ReloadUI = "Reload UI"
    L.ReloadUI_Desc = "Reload to apply settings."
    
end
