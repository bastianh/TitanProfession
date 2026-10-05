--[[
	Description: Titan Panel plugin that shows your Profession level
	Author: Eliote
	This addon was created and developed after Canettieri's "Titan Panel [Professions] Multi".
--]]

local ADDON_NAME, L = ...;
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
local VERSION = GetAddOnMetadata(ADDON_NAME, "Version")

local Elib = LibStub("Elib-4.0")

local TitanProfession = LibStub("AceAddon-3.0"):NewAddon("TitanProfession", "AceEvent-3.0")

---@type LibAddonCompat
local LAC = LibStub("LibAddonCompat-1.0")

local GetSpellInfo = function(spellIndex, book)
	if (C_SpellBook and C_SpellBook.GetSpellBookItemType) then
		local _, _, spellID = C_SpellBook.GetSpellBookItemType(spellIndex, Enum.SpellBookSpellBank.Player);
		if not spellID then return end ;

		local data = C_Spell.GetSpellInfo(spellID)
		if not data then return end
		-- name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon
		return data.name, data.rank, data.iconID, data.castTime, data.minRange, data.maxRange, data.spellID, data.originalIcon
	else
		return GetSpellInfo(spellIndex, book)
	end
end

local professionMaxLevel = {
	[LE_EXPANSION_CLASSIC] = 300,
	[LE_EXPANSION_BURNING_CRUSADE] = 375,
	[LE_EXPANSION_WRATH_OF_THE_LICH_KING] = 450,
	[LE_EXPANSION_CATACLYSM] = 525,
	[LE_EXPANSION_MISTS_OF_PANDARIA] = 600,
	[LE_EXPANSION_WARLORDS_OF_DRAENOR] = 700,
	[LE_EXPANSION_LEGION] = 800,
	[LE_EXPANSION_BATTLE_FOR_AZEROTH] = 975,
	[LE_EXPANSION_SHADOWLANDS] = 1125,
}

local Color = {}
Color.WHITE = "|cFFFFFFFF"
Color.RED = "|cFFDC2924"
Color.YELLOW = "|cFFFFF244"
Color.GREEN = "|cFF3DDC53"

local function GetMaxLevel()
	return professionMaxLevel[GetExpansionLevel() or LE_EXPANSION_SHADOWLANDS] or 1
end

local function CanLevelUp(profLvl, profMaxLvl)
	if profMaxLvl == 0 then
		return
	end
	if profMaxLvl == GetMaxLevel() then
		return
	end

	if profLvl > (profMaxLvl - 25) then
		return true
	end
end

local function GetProfLvlColor(profLvl, profMaxLvl)
	if CanLevelUp(profLvl, profMaxLvl) then
		if profLvl == profMaxLvl then
			return Color.RED
		else
			return Color.YELLOW
		end
	end

	return Color.WHITE
end

local menus = {
	{ type = "toggle", text = L["ShowMax"], var = "ShowMax", def = true },
	{ type = "toggle", text = L["HideNotLearned"], var = "HideNotLearned", def = true },
	{ type = "rightSideToggle" }
}

local function TitanProf(titanId, profIndex, defaultDesc, noProfHint)
	local profOffset
	local profNumAbilities = 0
	local startLevel

	local function UpdateVars(registry)
		local prof = select(profIndex, LAC:GetProfessions())
		local name, icon, level, maxLevel, numAbilities, offset, skillLine, skillModifier
		if (prof) then
			name, icon, level, maxLevel, numAbilities, offset, skillLine, skillModifier = LAC:GetProfessionInfo(prof)
		end
		if (registry) then
			registry.icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
			registry.tooltipTitle = name or defaultDesc

			-- Sets the title of the plugin the right-click menu, where you can show/hide titan plugins.
			if name then
				local isPrimary = profIndex <= 2
				if isPrimary then
					registry.menuText = defaultDesc .. " [" .. Color.GREEN .. name .. "|r]"
				else
					registry.menuText = defaultDesc .. "|r"
				end
			else
				registry.menuText = defaultDesc .. " [" .. Color.RED .. L["noprof"] .. "|r]"
			end
		end

		profOffset = offset
		profNumAbilities = numAbilities

		if (startLevel == nil or startLevel == 0 or level ~= nil or level == 0) then
			startLevel = level
		end

		return name, icon, level, maxLevel, numAbilities, offset, skillLine, skillModifier
	end

	local function ReloadPlugin()
		TitanPanelButton_UpdateButton(titanId)
	end

	local function GetProfSpell(offset, numAbilities)
		if offset and numAbilities > 0 then
			for i = 1, numAbilities do
				local spell = offset + i
				local name, _, _, castTime, minRange, maxRange = GetSpellInfo(spell, "Spell")
				if (name and castTime == 0 and minRange == 0 and maxRange == 0) then
					return spell
				end
			end
		end
	end

	local function GetChildInfo(id)
		local result = {}
		if not C_TradeSkillUI or not C_TradeSkillUI.GetAllProfessionTradeSkillLines then return result end

		local skillLines = C_TradeSkillUI.GetAllProfessionTradeSkillLines()
		for _, skillLine in ipairs(skillLines) do
			local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine)
			if (info and info.parentProfessionID == id) then
				table.insert(result, info)
			end
		end

		return result
	end

	local function CreateToolTip(self, tooltip)
		local GameTooltip = tooltip or _G.GameTooltip
		local name, _, level, maxLevel, numAbilities, offset, skillLine, skillModifier = UpdateVars()

		GameTooltip:SetText(name or defaultDesc, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)

		if maxLevel and maxLevel > 0 then
			if CanLevelUp(level, maxLevel) then
				GameTooltip:AddLine("|cFFFFFFFF" .. L["goTrainerHint"], nil, nil, nil, true);
			end

			if GetProfSpell(offset, numAbilities) then
				GameTooltip:AddLine("|cFFFFFFFF" .. L["tooltipHint"], nil, nil, nil, true);
			end

			GameTooltip:AddLine(" ");

			local bonusText = ""
			if (skillModifier and skillModifier > 0) then
				bonusText = Color.GREEN .. "+" .. skillModifier .. "|r(" .. Color.GREEN .. (skillModifier + level) .. "|r)"
			end

			GameTooltip:AddDoubleLine(L["tooltipLevel"], GetProfLvlColor(level, maxLevel) .. level .. bonusText);
			GameTooltip:AddDoubleLine(L["tooltipMaxLevel"], Color.WHITE .. maxLevel);

			local dif = level - startLevel
			if dif > 0 then
				GameTooltip:AddDoubleLine(L["thisSession"], Color.GREEN .. dif);
			end

			local child = GetChildInfo(skillLine)
			if child then
				--print(skillLine, #child)
				if next(child) then
					GameTooltip:AddLine(" ");
				end
				for _, info in pairs(child) do
					if (info.maxSkillLevel and info.maxSkillLevel > 0) then
						GameTooltip:AddDoubleLine(info.professionName, GetProfLvlColor(level, maxLevel) .. info.skillLevel .. "|r/" .. info.maxSkillLevel);
					end
				end
			end
		else
			GameTooltip:AddLine(noProfHint, nil, nil, nil, true);
		end
	end

	local function GetButtonText(self, id)
		local name, _, level, maxLevel, _, _, _, skillModifier = UpdateVars(self.registry)

		if not name then
			if TitanGetVar(id, "HideNotLearned") then
				return
			end
			return defaultDesc .. ": ", Color.RED .. L["noprof"]
		end

		local bonusText = ""
		if skillModifier and skillModifier > 0 then
			bonusText = Color.GREEN .. "+" .. skillModifier .. "|r(" .. Color.GREEN .. (skillModifier + level) .. "|r)"
		end

		local maxText = (TitanGetVar(id, "ShowMax") and ("|r/" .. Color.RED .. maxLevel)) or ""

		local session = ""
		local dif = level - startLevel
		if dif > 0 then
			session = Color.GREEN .. " [" .. dif .. Color.GREEN .. "]"
		end

		return name .. ": ", GetProfLvlColor(level, maxLevel) .. level .. bonusText .. maxText .. session .. "|r"
	end

	local function OnClick(_, button)
		if (button == "LeftButton") then
			local spell = GetProfSpell(profOffset, profNumAbilities)
			if spell then
				if (C_SpellBook and C_SpellBook.CastSpellBookItem) then
					C_SpellBook.CastSpellBookItem(spell, Enum.SpellBookSpellBank.Player)
				else
					CastSpell(spell, "Spell")
				end
			end
		end
	end

	Elib.Register({
		id = titanId,
		name = defaultDesc .. "|r",
		tooltip = L["noprof"],
		icon = "Interface\\Icons\\INV_Misc_QuestionMark",
		category = "Profession",
		version = VERSION,
		getButtonText = GetButtonText,
		onClick = OnClick,
		eventsTable = {
			SKILL_LINES_CHANGED = ReloadPlugin,
			PLAYER_ENTERING_WORLD = ReloadPlugin,
		},
		customTooltip = CreateToolTip,
		menus = menus
	})
end

function TitanProfession:OnInitialize()
	TitanProf("TITAN_PROF_1", LAC.PROFESSION_FIRST_INDEX, PROFESSIONS_FIRST_PROFESSION, PROFESSIONS_MISSING_PROFESSION) -- prof1
	TitanProf("TITAN_PROF_2", LAC.PROFESSION_SECOND_INDEX, PROFESSIONS_SECOND_PROFESSION, PROFESSIONS_MISSING_PROFESSION) -- prof2
	TitanProf("TITAN_PROF_4", LAC.PROFESSION_FISHING_INDEX, PROFESSIONS_FISHING, PROFESSIONS_FISHING_MISSING) -- fishing
	TitanProf("TITAN_PROF_5", LAC.PROFESSION_COOKING_INDEX, PROFESSIONS_COOKING, PROFESSIONS_COOKING_MISSING) -- cooking
	if (LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_CATACLYSM) then
		TitanProf("TITAN_PROF_3", LAC.PROFESSIONS_ARCHAEOLOGY_INDEX, PROFESSIONS_ARCHAEOLOGY, PROFESSIONS_ARCHAEOLOGY_MISSING) -- archaeology
	end
	if (LE_EXPANSION_LEVEL_CURRENT < LE_EXPANSION_BATTLE_FOR_AZEROTH) then
		TitanProf("TITAN_PROF_6", LAC.PROFESSION_FIRST_AID_INDEX, PROFESSIONS_FIRST_AID, PROFESSIONS_FIRST_AID_MISSING or PROFESSIONS_FIRST_AID) -- first aid
	end
end