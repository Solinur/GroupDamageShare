--[[
This lib is supposed to act as an interface between the API of Eso and potential addons that want to display Combat Data (e.g. dps)
I extracted it from Combat Metrics, for which most of the functions are designed. I believe however that it's possible that others can use it. 

Todo: 
work on the addon description 

Implement Debug Functions
Idea: Weaving Metrics
Idea: Life and Death

]]

local _

--Register with LibStub
local MAJOR, MINOR = "LibCombat", 11
local lib, oldminor = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end --the same or newer version of this lib is already loaded into memory

LibCombat = lib

--aliases

local wm = GetWindowManager()
local em = GetEventManager()
local _
local db
local reset = false
local data = {skillBars= {}}
local showdebug = false --or GetDisplayName() == "@Solinur"
local dev = GetDisplayName() == "@Solinur" -- or GetDisplayName() == "@Solinur"
local timeout = 800
local activetimeonheals = true
local ActiveCallbackTypes = {}
lib.ActiveCallbackTypes = ActiveCallbackTypes
local CustomAbilityTypeList = {}
local currentfight
local Events = {}
local EffectBuffer = {}
local lastdeaths = {}
local SlotSkills = {}
local IdToReducedSlot = {}
local lastskilluses = {}
local isInShadowWorld = false	-- used to prevent fight reset in Cloudrest when using a portal.

-- types of callbacks: Units, DPS/HPS, DPS/HPS for Group, Logevents

LIBCOMBAT_EVENT_MIN = 0
LIBCOMBAT_EVENT_UNITS = 0				-- LIBCOMBAT_EVENT_UNITS, {units}
LIBCOMBAT_EVENT_FIGHTRECAP = 1			-- LIBCOMBAT_EVENT_FIGHTRECAP, DPSOut, DPSIn, hps, HPSIn, healingOutTotal, dpstime, hpstime
LIBCOMBAT_EVENT_FIGHTSUMMARY = 2		-- LIBCOMBAT_EVENT_FIGHTSUMMARY, {fight}
LIBCOMBAT_EVENT_GROUPRECAP = 3			-- LIBCOMBAT_EVENT_GROUPRECAP, groupDPSOut, groupDPSIn, groupHPS, dpstime, hpstime
LIBCOMBAT_EVENT_DAMAGE_OUT = 4			-- LIBCOMBAT_EVENT_DAMAGE_OUT, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_DAMAGE_IN = 5			-- LIBCOMBAT_EVENT_DAMAGE_IN, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_DAMAGE_SELF = 6			-- LIBCOMBAT_EVENT_DAMAGE_SELF, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_HEAL_OUT = 7			-- LIBCOMBAT_EVENT_HEAL_OUT, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_HEAL_IN = 8				-- LIBCOMBAT_EVENT_HEAL_IN, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_HEAL_SELF = 9			-- LIBCOMBAT_EVENT_HEAL_SELF, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType
LIBCOMBAT_EVENT_EFFECTS_IN = 10			-- LIBCOMBAT_EVENT_EFFECTS_IN, timems, unitId, abilityId, changeType, effectType, stacks, sourceType
LIBCOMBAT_EVENT_EFFECTS_OUT = 11		-- LIBCOMBAT_EVENT_EFFECTS_OUT, timems, unitId, abilityId, changeType, effectType, stacks, sourceType
LIBCOMBAT_EVENT_GROUPEFFECTS_IN = 12	-- LIBCOMBAT_EVENT_GROUPEFFECTS_IN, timems, unitId, abilityId, changeType, effectType, stacks, sourceType
LIBCOMBAT_EVENT_GROUPEFFECTS_OUT = 13	-- LIBCOMBAT_EVENT_GROUPEFFECTS_OUT, timems, unitId, abilityId, changeType, effectType, stacks, sourceType
LIBCOMBAT_EVENT_PLAYERSTATS = 14		-- LIBCOMBAT_EVENT_PLAYERSTATS, timems, statchange, newvalue, statname
LIBCOMBAT_EVENT_RESOURCES = 15			-- LIBCOMBAT_EVENT_RESOURCES, timems, abilityId, powerValueChange, powerType
LIBCOMBAT_EVENT_MESSAGES = 16			-- LIBCOMBAT_EVENT_MESSAGES, timems, messageId, value
LIBCOMBAT_EVENT_DEATH = 17				-- LIBCOMBAT_EVENT_DEATH, timems, unitId, abilityId
LIBCOMBAT_EVENT_RESURRECTION = 18		-- LIBCOMBAT_EVENT_RESURRECTION, timems, unitId, self
LIBCOMBAT_EVENT_SKILL_TIMINGS = 19		-- LIBCOMBAT_EVENT_SKILL_TIMINGS, timems, reducedslot, abilityId, status
LIBCOMBAT_EVENT_MAX = 19

-- Messages:

LIBCOMBAT_MESSAGE_COMBATSTART = 1
LIBCOMBAT_MESSAGE_COMBATEND = 2
LIBCOMBAT_MESSAGE_WEAPONSWAP = 3

LIBCOMBAT_SKILLSTATUS_INSTANT = 1
LIBCOMBAT_SKILLSTATUS_BEGIN_DURATION = 2
LIBCOMBAT_SKILLSTATUS_BEGIN_CHANNEL = 3
LIBCOMBAT_SKILLSTATUS_SUCCESS = 4

-- Basic values
lib.name = "LibCombat"
lib.version = MINOR
lib.data = data
lib.cm = ZO_CallbackObject:New()

local BadAbility = {
	[50011] = true, 
	[51487] = true,
	[20546] = true,
	[69168] = true,
	[20667] = true,
	[27278] = true,
	[52515] = true,
	[20663] = true,
	[63510] = true,
	[41189] = true,
	[61898] = true, -- Minor Savagery, too spammy
}

local CustomAbilityName = {

	[-1] = "Unknown", -- Whenever there is no known abilityId
	[-2] = "Unknown", -- Whenever there is no known abilityId
	
	[75753] = GetAbilityName(75753), -- Line-breaker (Alkosh). pin abiltiy name so it can't get overridden
	[17906] = GetAbilityName(17906), -- Crusher (Glyph). pin abiltiy name so it can't get overridden
	[63003] = GetAbilityName(63003), -- Off-Balance
	
	[81274] = "(C) " .. GetAbilityName(81274) , -- Crown Store Poison, Rename to differentiate from normal Poison, which can apparently stack ?
	[81275] = "(C) " .. GetAbilityName(81275) , -- Crown Store Poison, Rename to differentiate from normal Poison, which can apparently stack ?
	
	} 
	
local CustomAbilityIcon = {}

local AbilityNameCache = {}

local function GetFormattedAbilityName(id)

	if id == nil then return "" end	
	
	local name = AbilityNameCache[id]
	
	if name == nil then 
	
		name = CustomAbilityName[id] or zo_strformat(SI_ABILITY_NAME, GetAbilityName(id))
		AbilityNameCache[id] = name
		
	end  
	
	return name
	
end

lib.GetFormattedAbilityName = GetFormattedAbilityName

local function GetFormattedAbilityIcon(id)

	if id == nil then return
	elseif type(id) == "string" then return id end
		
	local icon = CustomAbilityIcon[id] or GetAbilityIcon(id)
	return icon
	
end

lib.GetFormattedAbilityIcon = GetFormattedAbilityIcon

local critbonusabilities = {

	{
		["id"] = 31698,
		["effect"] = {[1] = 5, [2] = 10	}	-- Templar: Piercing Spear
	},
	{
		["id"] = 36641,
		["effect"] = {[1] = 5, [2] = 10	}	-- Nightblade: Hemorrhage
	},
	
}

local MajorForceAbility = {

	[40225] = true,
	[46533] = true,
	[46536] = true,
	[46539] = true,
	[61747] = true,
	[85154] = true,
	[86468] = true,
	[86472] = true,
	[86476] = true,
	[88891] = true,

}

local MinorForceAbility = {

	[61746] = true,
	[68595] = true,
	[68596] = true,
	[68597] = true,
	[68598] = true,
	[68628] = true,
	[68629] = true,
	[68630] = true,
	[68631] = true,
	[68632] = true,
	[68636] = true,
	[68638] = true,
	[68640] = true,
	[75766] = true,
	[76564] = true,
	[80984] = true,
	[80986] = true,
	[80996] = true,
	[80998] = true,
	[81004] = true,
	[81006] = true,
	[81012] = true,
	[81014] = true,
	[85611] = true,
	[103708] = true,

}

local SpecialBuffs = {

	21230,	-- Weapon/spell power enchant (Berserker)
	21578,	-- Damage shield enchant (Hardening)
	71067,	-- Trial By Fire: Shock
	71058,	-- Trial By Fire: Fire
	71019,	-- Trial By Fire: Frost
	71069,	-- Trial By Fire: Disease
	71072,	-- Trial By Fire: Poison
	49236,	-- Whitestrake's Retribution
	57170,	-- Blod Frenzy
	75726,	-- Tava's Favor
	75746,	-- Clever Alchemist
	61870,	-- Armor Master Resistance
	70352,	-- Armor Master Spell Resistance
	46539,	-- Major Force
	71107,  -- Briarheart
	
}

		
local SpecialDebuffs = {
	17906,  -- Crusher Enchantment
}

local abilityConversions = {

	[29012] = 48744, -- Dragon Leap --> CC Immunity
	[32719] = 48753, -- Take Flight --> CC Immunity
	[32715] = 48760, -- Ferocious Leap --> CC Immunity

	[29043] = 92507, -- Molten Weapons --> Major Sorcery
	[31874] = 92503, -- Igneous Weapons --> Major Sorcery
	[31888] = 92512, -- Molten Armaments --> Major Sorcery

	[23234] = 51392, -- Bolt Escape --> Bolt Escape Fatigue
	[23236] = 51392, -- Streak --> Bolt Escape Fatigue

	[33375] = 90587, -- Blur --> Major Evasion
	[35414] = 90593, -- Mirage --> Major Evasion
	[35419] = 90620, -- Double Take --> Major Evasion

	[25375] = 25376, -- Shadow Cloak --> Shadow Cloak
	[25380] = 25381, -- Shadowy Disguise --> Shadowy Disguise

	[86122] = 86224, -- Frost Cloak --> Major Resolve
	[86126] = 88758, -- Expansive Frost Cloak --> Major Resolve
	[86130] = 88761, -- Ice Fortress --> Major Resolve

	[22178] = 22179,  -- Sun Shield --> Sun Shield
	[22182] = 22183,  -- Radiant Ward --> Radiant Ward
	[22180] = 49091,  -- Blazing Shield --> Blazing Shield
					 
	[22149] = 48532,  -- Focused Charge --> Charge Snare
	[22161] = 48532,  -- Explosive Charge --> Charge Snare
	[15540] = 48532,  -- Toppling Charge --> Charge Snare
					 
	[26209] = 26220,  -- Restoring Aura --> Minor Magickasteal
	[26807] = 26809,  -- Radiant Aura --> Minor Magickasteal
	[26821] = 34366,  -- Repentance --> Repentance
					 
	[22304] = 22307,  -- Healing Ritual --> Healing Ritual
	[22327] = 22331,  -- Ritual of Rebirth --> Ritual of Rebirth
	[22314] = 22318,  -- Hasty Prayer --> Hasty Prayer
					 
	[28448] = 28450,  -- Critical Charge --> Critical Strike
	[38788] = 38789,  -- Stampede --> Critical Strike
	[38778] = 38781,  -- Critical Rush --> Critical Strike
					 
	[28719] = 48532,  -- Shield Charge --> Charge Snare
	[38401] = 48532,  -- Shielded Assault --> Charge Snare
	[38405] = 38408,  -- Invasion --> Invasion
					 
	[83600] = 85156,  -- Lacerate --> Lacerate
	[85187] = 85192,  -- Rend --> Rend
	[85179] = 85182,  -- Thrive in Chaos --> Thrive in Chaos
					 
	[29173] = 53881,  -- Weakness to Elements --> Major Breach
	[39089] = 62775,  -- Elemental Susceptibility --> Major Breach
	[39095] = 62787,  -- Elemental Drain --> Major Breach
					 
	[40116] = 88606,  -- Quick Siphon --> Minor Lifesteal
					 
	[29556] = 63015,  -- Evasion --> Major Evasion
	[39195] = 63019,  -- Shuffle --> Major Evasion
	[39192] = 63030,  -- Elude --> Major Evasion
					 
	[32632] = 48532,  -- Pounce --> Charge Snare
	[39105] = 48532,  -- Brutal Pounce --> Charge Snare
	[39104] = 48532,  -- Feral Pounce --> Charge Snare

	[103503] = 103521, -- Accelerate --> Minor Force
	[103503] = 103712, -- Race Against Time --> Minor Force

	[103478] = 108609, -- Undo --> Undo
	[103557] = 108621, -- Precognition --> Precognition
	[103564] = 108641, -- Temporal Guard --> Temporal Guard

	[38566] = 101161,  -- Rapid Maneuver --> Major Expedition
	[40211] = 101169,  -- Retreating Maneuver --> Major Expedition
	[40215] = 101178,  -- Charging Maneuver --> Major Expedition

	[61503] = 61504,   -- Vigor --> Vigor
	[61505] = 61506,   -- Echoing Vigor --> Echoing Vigor
	[61507] = 61509,   -- Resolving Vigor --> Resolving Vigor

	[38563] = 38564,   -- War Horn --> War Horn
	[40223] = 40224,   -- Aggressive Horn --> Aggressive Horn
	[40220] = 40221,   -- Sturdy Horn --> Sturdy Horn

	[38571] = 38572,   -- Purge --> Purge
	[40232] = 40233,   -- Efficient Purge --> Purge


	-- unclear: Malevolent Offering 33308 -- Heal ?
	-- unclear: Shrewd Offering 34721 -- Heal ?
	-- unclear: healthy Offering 34721 -- Heal ?

}

local validSkillStartResults = {

	[ACTION_RESULT_DAMAGE] = true, -- 1
	[ACTION_RESULT_CRITICAL_DAMAGE] = true, -- 2
	[ACTION_RESULT_HEAL] = true, -- 16
	[ACTION_RESULT_CRITICAL_HEAL] = true, -- 32
	[ACTION_RESULT_BLOCKED_DAMAGE] = true, -- 2151
	[ACTION_RESULT_DAMAGE_SHIELDED] = true, -- 2460
	[ACTION_RESULT_SNARED] = true, -- 2025
	[ACTION_RESULT_BEGIN] = true, -- 2200
	[ACTION_RESULT_EFFECT_GAINED] = true, -- 2240
	
}

local validSkillEndResults = {

	[ACTION_RESULT_EFFECT_GAINED] = true, -- 2240
	[ACTION_RESULT_EFFECT_FADED] = true, -- 2250
	
}

local UnitHandler = ZO_Object:Subclass()

function UnitHandler:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function UnitHandler:Initialize(name, id, unitType)

	if (unitType == nil or unitType == COMBAT_UNIT_TYPE_TARGET_DUMMY) then unitType = COMBAT_UNIT_TYPE_NONE end 
	
	if name~=nil and id~=nil and (unitType~=COMBAT_UNIT_TYPE_PLAYER or unitType~=COMBAT_UNIT_TYPE_PLAYER_PET or unitType~=COMBAT_UNIT_TYPE_GROUP) then
	
		self.bossId = data.bossnames[zo_strformat(SI_UNIT_NAME,name)]		-- if this is a boss, add the id (e.g. 1 for unitTag == "boss1")
		name = zo_strformat(SI_UNIT_NAME,(name or ""))
		
	end 
	
	self.name = name				-- name
	self.unitType = unitType		-- type of unit: group, pet or boss
	self.isFriendly = false
	self.damageOutTotal = 0
	self.groupDamageOut  = 0
	self.dpsstart = nil 				-- start of dps in ms
	self.dpsend = nil				 	-- end of dps in ms	
	
end

local FightHandler = ZO_Object:Subclass()

function FightHandler:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function FightHandler:Initialize()
	self.char = data.playername
	self.combatstart = 0 - timeout - 1	-- start of combat in ms
	self.combatend = -150				-- end of combat in ms
	self.combattime = 0 				-- total combat time
	self.dpsstart = nil 				-- start of dps in ms
	self.dpsend = nil				 	-- end of dps in ms
	self.hpsstart = nil 				-- start of hps in ms
	self.hpsend = nil				 	-- end of hps in ms
	self.dpstime = 0					-- total dps time	
	self.hpstime = 0					-- total dps time	
	self.units = {}				
	self.grplog = {}					-- log from group actions
	self.groupDamageOut = 0				-- dmg from and to the group
	self.groupDamageIn = 0				-- dmg from and to the group
	self.groupHealOut = 0				-- heal of the group
	self.groupHealIn = 0				-- heal of the group
	self.groupDPSOut = 0				-- group dps
	self.groupDPSIn = 0					-- incoming dps	on group
	self.groupHPSOut = 0				-- group hps
	self.groupHPSIn = 0					-- group hps
	self.damageOutTotal = 0				-- total damage out
	self.healingOutTotal = 0			-- total healing out
	self.damageInTotal = 0				-- total damage in
	self.damageInShielded = 0			-- total damage in shielded
	self.healingInTotal = 0				-- total healing in
	self.DPSOut = 0						-- dps
	self.HPSOut = 0						-- hps
	self.DPSIn = 0						-- incoming dps			
	self.HPSIn = 0						-- incoming hps		
	self.group = data.inGroup
	self.stats = {}
	self.playerid = data.playerid
end

local function Print(message, ...)
	df("[%s] %s", "libCombat", message:format(...))
end

function FightHandler:ResetFight()

	if data.inCombat ~= true then return end
	
	reset = true
	
	self:FinishFight()
	self:onUpdate()
	
	currentfight:PrepareFight()
end

function lib.ResetFight()
	currentfight:ResetFight()
end

local function GetShadowBonus()

	local divines = 0

	for i, key in pairs({EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST, EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET}) do
	
		trait, desc = GetItemLinkTraitInfo(GetItemLink(BAG_WORN, key, LINK_STYLE_DEFAULT))
	
		if trait == ITEM_TRAIT_TYPE_ARMOR_DIVINES then 
		
			divines = tonumber(desc:match("%d%.%d")) or tonumber(desc:match("%d,%d")) or 0 + divines

		end 
	end
	
	data.critBonusMundus = math.floor(9 * (1 + divines/100)) -- total mundus bonus, base is 9%
	
end

local function GetPlayerBuffs(timems)

	local newtime = timems - 200

	if Events.Effects.active == false then return end
	
	if data.playerid == nil then 
	
		zo_callLater(function() GetPlayerBuffs(timems) end, 100) 
		return
		
	end
	
	for i=1,GetNumBuffs("player") do
	
		-- buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType, abilityId, canClickOff, castByPlayer
	
		local _, _, endTime, _, stackCount, _, _, effectType, abilityType, _, abilityId, _, castByPlayer = GetUnitBuffInfo("player",i)
		
		local unitType = castByPlayer and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_NONE
		
		local stacks = math.max(stackCount,1)
		
		local playerid = data.playerid
		
		if abilityType == 5 and endTime > 0 and (not BadAbility[abilityId]) then 
					
			lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_EFFECTS_IN), LIBCOMBAT_EVENT_EFFECTS_IN, newtime, playerid, abilityId, EFFECT_RESULT_GAINED, effectType, stacks, unitType)
			--timems, unitId, abilityId, changeType, effectType, stacks, sourceType
			
		end
		
		if abilityId ==	13984 then GetShadowBonus() end
	end
end

local function GetOtherBuffs(timems)

	local newtime = timems - 200

	for _, unit in pairs(EffectBuffer) do
		
		for id, ability in pairs(unit) do
		
			local endTime, logdata = unpack(ability)
			
			logdata[2] = newtime
			
			lib.cm:FireCallbacks(("LibCombat"..logdata[1]), unpack(logdata))
		
		end		
	end
	
	EffectBuffer = {}
end

local function GetCritBonusFromPassives()

	local bonus = 0
	
	local skillDataTable = SKILLS_DATA_MANAGER.abilityIdToProgressionDataMap
	
	for k, ability in pairs(critbonusabilities) do
	
		local id = ability.id
	
		local skillData = skillDataTable[id].skillData	
		
		local purchased = skillData.isPurchased
		local rank = skillData.currentRank
		local lineData = skillData["skillLineData"]
		
		local line = lineData.skillLineIndex
		
		if purchased == true then bonus = ability.effect[rank] or 0 end
	
		if bonus > 0 then return {SKILL_TYPE_CLASS, line, bonus} end
	end
	
	return {}
	
end

local function GetCritBonusFromCP()

	local mightyCP = GetNumPointsSpentOnChampionSkill(5, 2) / 100
	local elfbornCP = GetNumPointsSpentOnChampionSkill(7, 3) / 100
	
	local mightyValue = 0.25 * mightyCP * (2 - mightyCP) + (mightyCP - 1) * (mightyCP - 0.5) * mightyCP * 2/250
	local elfbornValue = 0.25 * elfbornCP * (2 - elfbornCP) + (elfbornCP - 1) * (elfbornCP - 0.5) * elfbornCP * 2 / 250

	mightyValue = math.floor(mightyValue * 100)
	elfbornValue = math.floor(elfbornValue * 100)
	
	return mightyValue, elfbornValue
end

local function GetCurrentCP()
	local CP = {}
	
	for i = 1,9 do
	
		CP[i] = {}
		
		for j = 1,4 do
		
			CP[i][j] = GetNumPointsSpentOnChampionSkill(i, j)
			
		end
	end
	
	return CP
end

local function PurgeEffectBuffer(timems)

	for id, unit in pairs(EffectBuffer) do
	
		for _, data in pairs(unit) do
		
			local timeend = data[1]
		
			if timems/1000 > timeend then unit[id] = nil end
			
		end
	end
end

local function UpdateSlotSkillEvents()

	local events = Events.Skills
	
	if not events.active then return end
	
	events:UnregisterEvents()
	
	SlotSkills = {}
	
	local registeredIds = {}
	
	if data.skillBars == nil then data.skillBars = {} end

	for _, bar in pairs(data.skillBars) do
	
		for _, abilityId in pairs(bar) do
		
			if registeredIds[abilityId] == nil then 
			
				registeredIds[abilityId] = true
		
				local channeled, castTime = GetAbilityCastInfo(abilityId)
				
				local result = castTime > 0 and ACTION_RESULT_BEGIN or nil
				
				local result2 = castTime > 0 and ACTION_RESULT_EFFECT_GAINED or channeled and ACTION_RESULT_EFFECT_FADED or nil
				
				local convertedId = abilityConversions[abilityId] or abilityId

				table.insert(SlotSkills, {convertedId, result, false})
				table.insert(SlotSkills, {convertedId, result2, true})
			end
		end
	end	
	
	events:RegisterEvents()
end

local function GetCurrentSkillBars()

	local skillBars = data.skillBars
	
	local bar = data.bar
	
	skillBars[bar] = {}
	
	local currentbar = skillBars[bar]
	
	for i=1, 8 do 
	
		local id = GetSlotBoundId(i)
	
		currentbar[i] = id
		
		local reducedslot = (bar - 1) * 10 + i
		
		local convertedId = abilityConversions[id] or id
		
		IdToReducedSlot[convertedId] = reducedslot
		
	end	
	
	UpdateSlotSkillEvents()
	
end

local function onPlayerActivated()

	zo_callLater(GetCurrentSkillBars, 100)
	isInShadowWorld = false
	
end

function FightHandler:PrepareFight()

	local timems = GetGameTimeMilliseconds()
	
	if self.prepared ~= true then 
	
		self.combatstart = timems
		
		PurgeEffectBuffer(timems)
		
		self.date = GetTimeStamp()
		self.time = GetTimeString()
		self.zone = GetPlayerActiveZoneName()
		self.subzone = GetPlayerActiveSubzoneName()
		self.ESOversion = GetESOVersionString()
		self.account = data.accountname
		
		self.charData = {}
		
		local charData = self.charData
		
		charData.name = data.playername
		charData.raceId = GetUnitRaceId("player")
		charData.gender = GetUnitGender("player")
		charData.classId = GetUnitClassId("player")
		charData.level = GetUnitLevel("player")
		charData.CPtotal = GetUnitChampionPoints("player")
		
		self.CP = GetCurrentCP()
		
		if DoesUnitExist("boss1") then 
		
			self.bossfight = true
			self.bossname = zo_strformat(SI_UNIT_NAME,GetUnitName("boss1")) 
		end
		
		GetPlayerBuffs(timems)
		GetOtherBuffs(timems)
		
		self.stats.currentmagicka, _, _ = GetUnitPower("player", POWERTYPE_MAGICKA) 
		self.stats.currentstamina, _, _ = GetUnitPower("player", POWERTYPE_STAMINA) 		
		self.stats.currentulti, _, _ = GetUnitPower("player", POWERTYPE_ULTIMATE)
		
		data.critBonusPassive = GetCritBonusFromPassives()
		data.mightyCP, data.elfbornCP = GetCritBonusFromCP()
		
		self.prepared = true
		
		self.stats = {}
		self.startBar = data.bar
		GetCurrentSkillBars()
		self:GetNewStats(timems)		
	end	
	
	em:RegisterForUpdate("LibCombat_update", 500, function() self:onUpdate() end)
end

local function GetSkillBars()	

	local currentSkillBars = {}
	
	ZO_DeepTableCopy(data.skillBars, currentSkillBars)
	
	return currentSkillBars

end

local function GetEquip()

	local equip = {}

	for i = EQUIP_SLOT_ITERATION_BEGIN, EQUIP_SLOT_ITERATION_END do 
	
		equip[i] = GetItemLink(BAG_WORN, i, LINK_STYLE_DEFAULT)
		
	end
	
	return equip
	
end

function FightHandler:FinishFight()

	local charData = self.charData
	
	if charData == nil then return end
	
	charData.skillBars = GetSkillBars()
	charData.equip = GetEquip()

	local timems = GetGameTimeMilliseconds()
	self.combatend = timems
	self.combattime = zo_round((timems - self.combatstart)/10)/100
	
	self.starttime = math.min(self.dpsstart or self.hpsstart or 0, self.hpsstart or self.dpsstart or 0)
	self.endtime = math.max(self.dpsend or 0, self.hpsend or 0)
	self.activetime = math.max((self.endtime - self.starttime) / 1000, 1)
	
	data.majorForce = 0
	data.minorForce = 0	
	
	EffectBuffer = {}
	
	lastskilluses = {}
end
 
local function GetStat(stat) -- helper function to make code shorter
	return GetPlayerStat(stat, STAT_BONUS_OPTION_APPLY_BONUS)
end

local function GetCritbonus()

	local isactive = false
	
	local skillType, line, bonus = unpack(data.critBonusPassive)
		
	if bonus and bonus > 0 then 
	
		for i = 1, 6 do
		
			if GetAssignedSlotFromSkillAbility(skillType, line, i) ~= nil then 		-- Determines if an ability is equiped which "activates" the passive. Works both for templars and nightblades.
				
				isactive = true 
				break 
				
			end
		end
	end
	
	bonus = isactive and bonus or 0
	
	local mightyCP = data.mightyCP
	local elfbornCP = data.elfbornCP
	
	local total = 50 + data.critBonusMundus + bonus + data.majorForce + data.minorForce
	local spelltotal = elfbornCP + total
	local weapontotal = mightyCP + total
	
	return weapontotal, spelltotal

end

local TFSBonus = 0

local function onTFSChanged(_, changeType, _, _, _, _, _, stackCount, _, _, _, _, _, _, _, _, _)

	if (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED) and stackCount > 1 then 
 
		TFSBonus = (stackCount - 1) * 860
		
	else
		
		TFSBonus = 0
		
	end
end

local function GetStats()

	local weaponcritbonus, spellcritbonus = GetCritbonus()
	
	return {
		["maxmagicka"]		= GetStat(STAT_MAGICKA_MAX), 
		["spellpower"]		= GetStat(STAT_SPELL_POWER), 
		["spellcrit"]		= GetStat(STAT_SPELL_CRITICAL), 
		["spellcritbonus"]	= spellcritbonus,
		["spellpen"]		= GetStat(STAT_SPELL_PENETRATION), 
							
		["maxstamina"]		= GetStat(STAT_STAMINA_MAX), 
		["weaponpower"]		= GetStat(STAT_POWER), 
		["weaponcrit"]		= GetStat(STAT_CRITICAL_STRIKE), 
		["weaponcritbonus"]	= weaponcritbonus,
		["weaponpen"]		= GetStat(STAT_PHYSICAL_PENETRATION) + TFSBonus, 
							
		["maxhealth"]		= GetStat(STAT_HEALTH_MAX), 		
		["physres"]			= GetStat(STAT_PHYSICAL_RESIST), 
		["spellres"]		= GetStat(STAT_SPELL_RESIST), 
		["critres"]			= GetStat(STAT_CRITICAL_RESISTANCE)
	}
end

local maxcrit = 21912 -- fallback value, will be determined dynamically later

local lastGetNewStatsCall = 0

function FightHandler:GetNewStats(timems)
	
	em:UnregisterForUpdate("COMBATMETRICS_GETNEWSTATS")
	
	timems = timems or GetGameTimeMilliseconds()
	
	local lastcalldelta = timems - lastGetNewStatsCall
	
	if lastcalldelta < 100 then 
	
		em:RegisterForUpdate("COMBATMETRICS_GETNEWSTATS", (100 - lastcalldelta), function() self:GetNewStats() end)
	
		return 
		
	end

	if NonContiguousCount(ActiveCallbackTypes[LIBCOMBAT_EVENT_PLAYERSTATS]) == 0 then return end
	
	lastGetNewStatsCall = timems
	
	local stats = self.stats
	
	for statName, newValue in pairs(GetStats()) do
	
		if statName == "spellcrit" or statName == "weaponcrit" then newValue = math.min(newValue, maxcrit) end
	
		if stats["current"..statName] == nil or stats["max"..statName] == nil then 
		
			lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_PLAYERSTATS), LIBCOMBAT_EVENT_PLAYERSTATS, timems, 0, newValue, statName)
			
			stats["current"..statName] = newValue 
			stats["max"..statName] = newValue 
			
		elseif stats["current"..statName] ~= newValue and timems ~= nil and data.inCombat then 
		
			lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_PLAYERSTATS), LIBCOMBAT_EVENT_PLAYERSTATS, timems, newValue - stats["current"..statName], newValue, statName)
			
			stats["current"..statName] = newValue
			stats["max"..statName] = math.max(stats["max"..statName] or newValue, newValue)
			
		end
	end
end

function FightHandler:AddCombatEvent(timems, result, targetUnitId, value, eventid)

	if eventid == LIBCOMBAT_EVENT_DAMAGE_OUT then 		--outgoing dmg
	
		self.damageOutTotal = self.damageOutTotal + value
		
		self.units[targetUnitId]["damageOutTotal"] = self.units[targetUnitId]["damageOutTotal"] + value
		
		self.dpsstart = self.dpsstart or timems
		self.dpsend = timems
		
	elseif eventid == LIBCOMBAT_EVENT_DAMAGE_IN then 	--incoming dmg
	
		if result == ACTION_RESULT_DAMAGE_SHIELDED then
		
			self.damageInShielded = self.damageInShielded + value
			
		else 
		
			self.damageInTotal = self.damageInTotal + value
			
		end
		
	elseif eventid == LIBCOMBAT_EVENT_HEAL_OUT then --outgoing heal
	
		self.healingOutTotal = self.healingOutTotal + value
		
		if activetimeonheals then 
		
			self.hpsstart = self.hpsstart or timems 
			self.hpsend = timems
			
		end
		
	elseif eventid == LIBCOMBAT_EVENT_HEAL_IN then --incoming heals
		
		self.healingInTotal = self.healingInTotal + value
		
	elseif eventid == LIBCOMBAT_EVENT_HEAL_SELF then --outgoing heal
		
		self.healingInTotal = self.healingInTotal + value
		self.healingOutTotal = self.healingOutTotal + value
		
		if activetimeonheals then 
		
			self.hpsstart = self.hpsstart or timems 
			self.hpsend = timems
			
		end
	end	
end

function FightHandler:UpdateStats()

	if (self.dpsend == nil and self.hpsend == nil) or (self.dpsstart == nil and self.hpsstart == nil) then return end
	
	local dpstime = math.max(((self.dpsend or 1) - (self.dpsstart or 0)) / 1000, 1)
	local hpstime = math.max(((self.hpsend or 1) - (self.hpsstart or 0)) / 1000, 1)
	
	self.dpstime = dpstime
	self.hpstime = hpstime
	
	self:UpdateGrpStats()

	self.DPSOut = math.floor(self.damageOutTotal / dpstime + 0.5)
	self.HPSOut = math.floor(self.healingOutTotal / hpstime + 0.5)
	self.DPSIn = math.floor(self.damageInTotal / dpstime + 0.5)
	self.HPSIn = math.floor(self.healingInTotal / hpstime + 0.5)
	
	local data = {
		["DPSOut"] = self.DPSOut, 
		["DPSIn"] = self.DPSIn,  
		["HPSOut"] = self.HPSOut,  
		["HPSIn"] = self.HPSIn,  
		["healingOutTotal"] = self.healingOutTotal,  
		["dpstime"] = dpstime,  
		["hpstime"] = hpstime,
	}
	
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_UNITS), LIBCOMBAT_EVENT_UNITS, self.units)
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_FIGHTRECAP), LIBCOMBAT_EVENT_FIGHTRECAP, data) 
	
end

function FightHandler:UpdateGrpStats() -- called by onUpdate
	
	if not (data.inGroup and Events.CombatGrp.active) then return end
	
	local iend = (self.grplog and #self.grplog) or 0
	
	if iend > 1 then
		
		for i = iend, 1, -1 do 			-- go backwards for easier deletions
			
			local line = self.grplog[i]
			local unitId, value, action = unpack(line)
			
			local unit = self.units[unitId]
			
			if (action=="heal" and unit and unit.isFriendly == true) then --only events of identified units are removed. The others might be identified later.
				
				self.groupHealOut = self.groupHealOut + value
				table.remove(self.grplog,i)
			
			elseif unit and unit.isFriendly == false and action=="dmg" then
				
				unit.groupDamageOut = unit.groupDamageOut + value
				self.groupDamageOut = self.groupDamageOut + value
				table.remove(self.grplog,i)
			
			elseif unit and unit.isFriendly == true and action=="dmg" then
				
				self.groupDamageIn = self.groupDamageIn + value
				table.remove(self.grplog,i) 
			
			end
		end
	end
	
	local dpstime = self.dpstime
	local hpstime = self.hpstime
	
	self.groupHealIn = self.groupHealOut
	
	self.groupDPSOut = math.floor(self.groupDamageOut / dpstime + 0.5)
	self.groupDPSIn = math.floor(self.groupDamageIn / dpstime + 0.5)
	self.groupHPSOut = math.floor(self.groupHealOut / hpstime + 0.5)
	
	self.groupHPSIn = self.groupHPSOut
	
	local data = {
	
	["groupDPSOut"] = self.groupDPSOut, 
	["groupDPSIn"] = self.groupDPSIn, 
	["groupHPSOut"] = self.groupHPSOut, 
	["dpstime"] = dpstime, 
	["hpstime"] = hpstime
	
	}
	
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_GROUPRECAP), LIBCOMBAT_EVENT_GROUPRECAP, data)

end

function FightHandler:onUpdate()
	--reset data
	if reset == true or (IsUnitDeadOrReincarnating("player")==false and data.inCombat==false and self.combatend>0 and (GetGameTimeMilliseconds() > (self.combatend + timeout)) ) then
	
		reset = false	
		
		self:UpdateStats()
		
		if showdebug == true and (self.damageOutTotal>0 or self.healingOutTotal>0 or self.damageInTotal>0) then
		
			df("Time: %.2fs (DPS) | %.2fs (HPS) ", self.dpstime, self.hpstime)
			df("Dmg: %d (DPS: %d)", self.damageOutTotal, self.DPSOut)
			df("Heal: %d (HPS: %d)", self.healingOutTotal, self.HPSOut)
			df("IncDmg: %d (Shield: %d, IncDPS: %d)", self.damageInTotal, self.damageInShielded, self.DPSIn)
			df("IncHeal: %d (IncHPS: %d)", self.healingInTotal, self.HPSIn)
			
			if data.inGroup and Events.CombatGrp.active then
			
				df("GrpDmg: %d (DPS: %d)", self.groupDamageOut, self.groupDPSOut)
				df("GrpHeal: %d (HPS: %d)", self.groupHealOut, self.groupHPS)
				df("GrpIncDmg: %d (IncDPS: %d)", self.groupDamageIn, self.groupDPSIn)
				
			end
		end
		
		if showdebug == true then d("lib: resetting...") end
		
		self.grplog = {}
		
		lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_FIGHTSUMMARY), LIBCOMBAT_EVENT_FIGHTSUMMARY, self)

		currentfight = FightHandler:New()
		
		em:UnregisterForUpdate("LibCombat_update")
		
	elseif data.inCombat == true then
	
		self:UpdateStats()
		
	end 
	
end

-- Event Functions 

local function onCombatState(event, inCombat)  -- Detect Combat Stage

	if isInShadowWorld and IsUnitDead("player") == false then -- prevent fight reset in Cloudrest when using a portal.
		
		if dev then d("[%.3f] Prevented combat state change due to Shadow World!", GetGameTimeMilliseconds()/1000) end
		return 
		
	end

	if inCombat ~= data.inCombat then     -- Check if player state changed
  
		local timems = GetGameTimeMilliseconds()
		
		data.inCombat = inCombat or false
		
		if inCombat then
		
			if showdebug == true or dev then df("[%.3f] Entering combat.", GetGameTimeMilliseconds()/1000) end
			
			lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_MESSAGES), LIBCOMBAT_EVENT_MESSAGES, timems, LIBCOMBAT_MESSAGE_COMBATSTART, 0)
			
			currentfight:PrepareFight()
			
		else 
		
			if showdebug == true or dev then df("[%.3f] Leaving combat.", GetGameTimeMilliseconds()/1000) end
			
			currentfight:FinishFight()
			
			if charData == nil then return end

			lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_MESSAGES), LIBCOMBAT_EVENT_MESSAGES, timems, LIBCOMBAT_MESSAGE_COMBATEND, 0)
			
		end
	end
end

local function onBossesChanged(_) -- Detect Bosses

	data.bosses=0
	data.bossnames={}
	
	for i = 1, 12 do
	
		local unitTag = 'boss' .. i
		
		if DoesUnitExist(unitTag) then
		
			data.bosses = i
			
			local name = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
			
			data.bossnames[name] = true
			currentfight.bossfight = true
			
		else return
		
		end
	end
end

-- Buffs/Dbuffs

local GROUP_EFFECT_NONE = 0
local GROUP_EFFECT_IN = 1
local GROUP_EFFECT_OUT = 2 

--(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)

local lastPurge = 0

local function AddtoEffectBuffer(eventid, timems, unitId, abilityId, changeType, effectType, stacks, sourceType, endTime)

	local data = {endTime, {eventid, timems, unitId, abilityId, changeType, effectType, stacks, sourceType}}
	
	local unit = EffectBuffer[unitId]

	if unit == nil then
	
		EffectBuffer[unitId] = {[abilityId] = data}

	else
	
		unit[abilityId] = data
		
	end
		
	if timems - lastPurge > 1000 then 
	
		PurgeEffectBuffer(timems)
		lastPurge = timems
	
	end
end

local function onShadowWorld( _, changeType)

	isInShadowWorld = changeType == EFFECT_RESULT_GAINED
	if dev then df("[%.3f] Shadow: %s", GetGameTimeMilliseconds()/1000, tostring(isInShadowWorld)) end
	
end

local function onMageExplode( _, changeType, _, _, unitTag, _, endTime, stackCount, _, _, effectType, abilityType, _, unitName, unitId, abilityId, sourceType)

	currentfight:ResetFight()	-- special tracking for The Mage in Aetherian Archives. It will reset the fight when the mage encounter starts.

end

local function BuffEventHandler(isspecial, groupeffect, _, changeType, _, _, unitTag, _, endTime, stackCount, _, _, effectType, abilityType, _, unitName, unitId, abilityId, sourceType)

	if BadAbility[abilityId] == true then return end

	if unitTag and string.sub(unitTag, 1, 5) == "group" and AreUnitsEqual(unitTag, "player") then return end
	if unitTag and string.sub(unitTag, 1, 11) ~= "reticleover" and (AreUnitsEqual(unitTag, "reticleover") or AreUnitsEqual(unitTag, "reticleoverplayer") or AreUnitsEqual(unitTag, "reticleovertarget")) then return end

	if (changeType ~= EFFECT_RESULT_GAINED and changeType ~= EFFECT_RESULT_FADED and (changeType ~= EFFECT_RESULT_UPDATED and stackCount > 1)) or unitName == "Offline" or unitId == nil then return end
	
	local timems = GetGameTimeMilliseconds()
	
	-- if dev and abilityId == -1 and unitTag == "player" then df("[%.3f] %s %s", timems/1000, changeType == EFFECT_RESULT_GAINED and "Got" or "Lost", GetFormattedAbilityName(abilityId)) end
	
	-- if showdebug==true then d(changeType..","..GetAbilityName(abilityId)..", ET:"..effectType..","..abilityType..","..unitTag) end
	
	local eventid = groupeffect == GROUP_EFFECT_IN and LIBCOMBAT_EVENT_GROUPEFFECTS_IN or groupeffect == GROUP_EFFECT_OUT and LIBCOMBAT_EVENT_GROUPEFFECTS_OUT or string.sub(unitTag, 1, 6) == "player" and LIBCOMBAT_EVENT_EFFECTS_IN or LIBCOMBAT_EVENT_EFFECTS_OUT
	local stacks = (isspecial and 0) or math.max(1, stackCount)
	
	local inCombat = currentfight.prepared
	
	if inCombat ~= true and unitTag ~= "player" and (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED) then
	
		AddtoEffectBuffer(eventid, timems, unitId, abilityId, changeType, effectType, stacks, sourceType, endTime)
		return 
		
	elseif inCombat == true then 
	
		if unitTag == "player" then currentfight:GetNewStats(timems) end
		lib.cm:FireCallbacks(("LibCombat"..eventid), eventid, timems, unitId, abilityId, changeType, effectType, stacks, sourceType)
		
	end
end

local function onMajorForceChanged( _, changeType)
	
	if changeType == 1 then data.majorForce = 15 
	elseif changeType == 2 then data.majorForce = 0 end

end

local function onMinorForceChanged( _, changeType)
	
	if changeType == 1 then data.minorForce = 10 
	elseif changeType == 2 then data.minorForce = 0 end

end	

local function onEffectChanged(...)
	BuffEventHandler(false, GROUP_EFFECT_NONE, ...)		-- (isspecial, groupeffect, ...)
end

local function onGroupEffectOut(...)
	BuffEventHandler(false, GROUP_EFFECT_OUT, ...)		-- (isspecial, groupeffect, ...)
end

local function onGroupEffectIn(...)
	BuffEventHandler(false, GROUP_EFFECT_IN, ...)		-- (isspecial, groupeffect, ...)
end

local function SpecialBuffEventHandler(isdebuff, _ , result , _ , _ , _ , _ , _ , _ , unitName , targetType , _ , _ , damageType , _ , _ , unitId , abilityId)

	if BadAbility[abilityId] == true then return end
	
	if zo_strformat(SI_UNIT_NAME,unitName) ~= data.playername then return end
	
	local changeType = result == ACTION_RESULT_EFFECT_GAINED_DURATION and 1 or result == ACTION_RESULT_EFFECT_FADED and 2 or nil
	
	if showdebug == true then d("Custom: "..(data.CustomAbilityName[abilityId] or zo_strformat(SI_ABILITY_NAME,GetAbilityName(abilityId))).."("..(changeType==1 and "gain" or changeType==2 and "loss" or "??" )..")") end
	
	local effectType = isdebuff and BUFF_EFFECT_TYPE_DEBUFF or BUFF_EFFECT_TYPE_BUFF
	BuffEventHandler(true, GROUP_EFFECT_NONE, _, changeType, _, _, _, _, _, _, _, _, effectType, ABILITY_TYPE_BONUS, _, unitName, unitId, abilityId, sourceType)
end

local function onSpecialBuffEvent(...)
	SpecialBuffEventHandler(false, ...)		-- (isdebuff, ...)
end

local function onSpecialDebuffEvent(...)
	SpecialBuffEventHandler(true, ...)		-- (isdebuff, ...)
end

local function onSpecialBuffEventNoSelf(...)
	local _ , _ , _ , _ , _ , _ , _ , sourceType , _ , targetType , _ , _ , _ , _ , _ , _ , _ = ...
	if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER then return end
	SpecialBuffEventHandler(false, ...)		-- (isdebuff, ...)
end

local function onSpecialDebuffEventNoSelf(...)
	local _ , _ , _ , _ , _ , _ , _ , sourceType , _ , targetType , _ , _ , _ , _ , _ , _ , _ = ...
	if sourceType == COMBAT_UNIT_TYPE_PLAYER and targetType == COMBAT_UNIT_TYPE_PLAYER then return end
	SpecialBuffEventHandler(true, ...)		-- (isdebuff, ...)
end

local IsTypeFriendly={						-- for debug purposes, maybe one can use this to add more custom buffs.
	[COMBAT_UNIT_TYPE_PLAYER]=true,
	[COMBAT_UNIT_TYPE_PLAYER_PET]=true,
	[COMBAT_UNIT_TYPE_GROUP]=true,
	[COMBAT_UNIT_TYPE_TARGET_DUMMY]=false,
	[COMBAT_UNIT_TYPE_OTHER]=false,
}

local function onCustomEvent(_, _, _, _, _, _, _, sourceType, _, targetType, _, _, _, _, _, _, abilityId)
	if sourceType ~= nil and targetType ~= nil and IsTypeFriendly[sourceType]~=IsTypeFriendly[targetType] then 
		CustomAbilityTypeList[abilityId] = BUFF_EFFECT_TYPE_DEBUFF
	else
		CustomAbilityTypeList[abilityId] = CustomAbilityTypeList[abilityId] or BUFF_EFFECT_TYPE_BUFF
	end
end  

function lib.GetCustomAbilityList()
	return CustomAbilityTypeList
end

local function onBaseResourceChanged(_,unitTag,_,powerType,powerValue,_,_) 

	if unitTag ~= "player" then return end
	if (powerType ~= POWERTYPE_MAGICKA and powerType ~= POWERTYPE_STAMINA and powerType ~= POWERTYPE_ULTIMATE) or (data.inCombat == false) then return end 
	
	local timems = GetGameTimeMilliseconds()
	local powerValueChange
	local aId 
	
	local stats = currentfight.stats
	local lastabilities = data.lastabilities
	
 	if powerType == POWERTYPE_MAGICKA then
	
		aId = -1
	
		powerValueChange = powerValue - (stats.currentmagicka or powerValue)
		stats.currentmagicka = powerValue
		
		if powerValueChange == 0 then return end
		
		if showdebug == true then d("Skill cost: "..powerValueChange) end
		
		for i = #lastabilities, 1, -1 do
		
			local values = lastabilities[i]
		
			local ratio = powerValueChange / values[3]
			
			if showdebug == true and powerType == values[4] then d("Ratio: "..ratio) end
			
			local goodratio = ratio >= 0.98 and ratio <= 1.02
			
			if (powerValueChange == values[3] or goodratio) and powerType == values[4] then
			
				aId = values[2]					
				table.remove(lastabilities, i)
				
				break
				
			end
		end
	
			
		if aId == -1 and powerValueChange == GetStat(STAT_MAGICKA_REGEN_COMBAT) then 

			aId = 0
			
		end
		
	elseif powerType == POWERTYPE_STAMINA then
	
		aId = -2
	
		powerValueChange = powerValue - (stats.currentstamina or powerValue)
		stats.currentstamina = powerValue
		
		if powerValueChange == 0 then return end
	
		for i = #lastabilities, 1, -1 do
		
			local values = lastabilities[i]
		
			local ratio = powerValueChange / values[3]
			
			if showdebug == true and powerType == values[4] then d("Ratio: "..ratio) end
			
			local goodratio = ratio >= 0.98 and ratio <= 1.02
			
			if goodratio and powerType == values[4] then 
			
				aId = values[2]
				table.remove(lastabilities, i)
				
				break
				
			end
		end
		
		if powerValueChange == GetStat(STAT_STAMINA_REGEN_COMBAT) and aId == -2 then 

			aId = 0
 
		elseif aId == -2 then 
		
			local bashratio = -GetAbilityCost(21970) * 5/3 / powerValueChange
			local dodgeratio = -GetAbilityCost(28549) / powerValueChange
			
			local goodbashratio = bashratio >= 0.98 and bashratio <= 1.02
			local gooddodgeratio = dodgeratio >= 0.98 and dodgeratio <= 1.02
			
			if goodbashratio then 
			
				aId = 21970
				
			elseif gooddodgeratio then 
			
				aId = 28549
				
			end
		end
		
	elseif powerType == POWERTYPE_ULTIMATE then
		
		aId = 0
		
		powerValueChange = powerValue - (stats.currentulti or powerValue)
		stats.currentulti = powerValue
		
		if powerValueChange == 0 then return end
		
	end
	
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_RESOURCES), LIBCOMBAT_EVENT_RESOURCES, timems, aId, powerValueChange, powerType)
end

local function onSlotUpdate(_, slot)

	if data.inCombat == false or slot > 8 then return end
	
	local timems = GetGameTimeMilliseconds()
	local cost, powerType = GetSlotAbilityCost(slot)
	local abilityId = GetSlotBoundId(slot)
	local lastabilities = data.lastabilities
	
	if Events.Resources.active and slot > 2 and (powerType == 0 or powerType == 6) then 
	
		table.insert(lastabilities,{timems, abilityId, -cost, powerType})
		
		if #lastabilities > 10 then table.remove(lastabilities, 1) end
	
	end
	
	if Events.Skills.active then
	
		local convertedId = abilityConversions[abilityId] or abilityId
	
		lastskilluses[convertedId] = timems
	
	end
end

--(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
local function onResourceChanged (_, result, _, _, _, _, _, _, targetName, _, powerValueChange, powerType, _, _, sourceUnitId, targetUnitId, abilityId) 
	
	local lastabilities = data.lastabilities
	
	if data.playerid == nil and zo_strformat(SI_UNIT_NAME, targetName) == data.playername then data.playerid = targetUnitId end
	
	local timems = GetGameTimeMilliseconds()
	
	if (powerType ~= 0 and powerType ~= 6) or data.inCombat == false or powerValueChange < 1 then return end 
	
	if result == ACTION_RESULT_POWER_DRAIN then powerValueChange = -powerValueChange end
	
	table.insert(lastabilities,{timems, abilityId, powerValueChange, powerType})
	
	if #lastabilities > 10 then table.remove(lastabilities, 1) end
end

local function onWeaponSwap(_, _)

	data.bar = ACTION_BAR_ASSIGNMENT_MANAGER.currentHotbarCategory + 1
	
	GetCurrentSkillBars()
	
	local inCombat = currentfight.prepared
	
	if inCombat == true then  
	
		local timems = GetGameTimeMilliseconds()
		lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_MESSAGES), LIBCOMBAT_EVENT_MESSAGES, timems, LIBCOMBAT_MESSAGE_WEAPONSWAP, data.bar)
		
		currentfight:GetNewStats(timems)
		
	end
end

local function OnDeathStateChanged(_, unitTag, isDead)

	if not isdead or data.inCombat == false then return end
	
	local name = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
	
	local lasttime = lastdeaths[name]
	
	local timems = GetGameTimeMilliseconds()
	
	unitId = data.groupmembers[name]
	
	if (lasttime and lasttime - timems < 100) or not unitId then return end
	
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_DEATH), LIBCOMBAT_EVENT_DEATH, timems, unitId, -1)

	if isDead then Print("[%.3f] DS: %s died!", timems/1000, name ) end
	
	-- death (for group display, also works for different zones)

end

local function OnPlayerReincarnated()

	Print("[%.3f] Revive!", GetGameTimeMilliseconds()/1000)

end

local function OnDeath(_, result, _, abilityName, _, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, _, sourceUnitId, targetUnitId, abilityId) 

	if targetUnitId == nil or targetUnitId == 0 or data.inCombat == false then return end
	
	local unitdata = currentfight.units[targetUnitId]
	
	if unitdata == nil or unitdata.type ~= COMBAT_UNIT_TYPE_GROUP then return end
	
	name = unitdata.name or zo_strformat(SI_UNIT_NAME, targetName) or ""
	
	lastdeaths[name] = GetGameTimeMilliseconds()
	
	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_DEATH), LIBCOMBAT_EVENT_DEATH, timems, targetUnitId, abilityId)
	
	Print("[%.3f] CE: %s died! (%d - %s) (%s -> %s)", GetGameTimeMilliseconds()/1000, name, result, GetFormattedAbilityName(abilityId), tostring(sourceUnitId), tostring(targetUnitId))
	
end

local function OnResurrectResult(_, targetCharacterName, result, targetDisplayName)

	if result ~= RESURRECT_RESULT_SUCCESS then return end

	name = zo_strformat(SI_UNIT_NAME, targetCharacterName) or ""
	
	unitId = data.groupmembers[name]
	
	if not unitId then return end	

	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_RESURRECTION), LIBCOMBAT_EVENT_RESURRECTION, timems, data.playerid, unitId)
	
	Print("[%.3f] Rezzed %s", GetGameTimeMilliseconds()/1000, targetCharacterName )
	
end

local function OnResurrectRequest(_, requesterCharacterName, timeLeftToAccept, requesterDisplayName)

	name = zo_strformat(SI_UNIT_NAME, requesterCharacterName) or ""
	
	unitId = data.groupmembers[name]
	
	if not unitId then return end	

	lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_RESURRECTION), LIBCOMBAT_EVENT_RESURRECTION, timems, unitId, data.playerid)

	Print("[%.3f] Rezzed by %s", GetGameTimeMilliseconds()/1000, requesterCharacterName )

end

local function onGroupChange()

	data.inGroup = IsUnitGrouped("player")
	
	data.groupmemberdisplaynames = {}
	
	if data.inGroup == true then
	
		for i = 1,GetGroupSize() do 
		
			local name = zo_strformat(SI_UNIT_NAME, GetUnitName("group"..i))
			local displayname = zo_strformat(SI_UNIT_NAME, GetUnitDisplayName("group"..i))
			
			data.groupmemberdisplaynames[name] = displayname
		end	
	end
end

local function CheckUnit(unitName, unitId, unitType, timems)

	local currentunits = currentfight.units
	
	if unitType == COMBAT_UNIT_TYPE_PLAYER then 
	
		data.playerid = unitId
		currentfight.playerid = unitId
		
	end 
	
	if currentunits[unitId] == nil then currentunits[unitId] = UnitHandler:New(unitName, unitId, unitType) end
	
	local unit = currentunits[unitId]
	
	if unit.name == "Offline" or unit.name == "" then unit.name = zo_strformat(SI_UNIT_NAME,unitName) end 
	
	if unit.unitType ~= COMBAT_UNIT_TYPE_GROUP and unitType==COMBAT_UNIT_TYPE_GROUP then unit.unitType = COMBAT_UNIT_TYPE_GROUP end
	if unit.unitType == COMBAT_UNIT_TYPE_GROUP or unit.unitType == COMBAT_UNIT_TYPE_PLAYER or unit.unitType == COMBAT_UNIT_TYPE_PLAYER_PET then unit.isFriendly = true end

	unit.dpsstart = unit.dpsstart or timems
	unit.dpsend = timems
	
	if unitType == COMBAT_UNIT_TYPE_GROUP then 
	
		unit.displayname = data.groupmemberdisplaynames[unitName]
	
		local groupdata = data.groupmembers
		
		if groupdata then groupdata[unitName] = unitId end 
	
	end
end

--(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId) 

local function CombatEventHandler(isheal, _ , result , _ , _ , _ , _ , sourceName , sourceType , targetName , targetType , hitValue , powerType , damageType , _ , sourceUnitId , targetUnitId , abilityId)  -- called by Event

	--d({eventCode=eventCode, result=result, isError=isError, abilityName=abilityName, abilityGraphic=abilityGraphic, abilityActionSlotType=abilityActionSlotType, sourceName=sourceName, sourceType=sourceType, targetName=targetName, targetType=targetType, hitValue=hitValue, powerType=powerType, damageType=damageType, log=log, sourceUnitId=sourceUnitId, targetUnitId=targetUnitId, abilityId})
	
	if hitValue<2 or (not (sourceUnitId > 0 and targetUnitId > 0)) or (data.inCombat == false and (result==ACTION_RESULT_DOT_TICK_CRITICAL or result==ACTION_RESULT_DOT_TICK or isheal) ) or targetType==2 then return end -- only record if both unitids are valid or player is in combat or a non dot damage action happens or the target is not a pet
	local timems = GetGameTimeMilliseconds()
	
	CheckUnit(sourceName, sourceUnitId, sourceType, timems)
	CheckUnit(targetName, targetUnitId, targetType, timems)

	local isout = (sourceType == 1 or sourceType == 2)
	local isin = targetType == 1
	
	local eventid = LIBCOMBAT_EVENT_DAMAGE_OUT + (isheal and 3 or 0) + ((isout and isin) and 2 or isin and 1 or 0)

	if currentfight.dpsstart == nil then currentfight:PrepareFight() end -- get stats before the damage event
	
	damageType = (isheal and powerType) or damageType
	
	currentfight:AddCombatEvent(timems, result, targetUnitId, hitValue, eventid)
	
	lib.cm:FireCallbacks(("LibCombat"..eventid), eventid, timems, result, sourceUnitId, targetUnitId, abilityId, hitValue, damageType)
end

local function onCombatEventDmg(...)
	CombatEventHandler(false, ...)	-- (isheal, ...)
end

local function onCombatEventDmgIn(...)
	-- avoid counting actions to oneself twice
	local _, _, _, _, _, _, _, sourceType, _, targetType , _, _, _, _, _, _, _ = ...
	
	if (sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET) and (targetType == COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_PLAYER_PET) then return end
	
	CombatEventHandler(false, ...)	-- (isheal, ...)
end

local function onCombatEventHeal(...)  
	local _, _, _, _, _, _, _, _, _, _, hitValue, _, _, _, _, _, _ = ...
	
	if hitValue<2 or (data.inCombat == false and (GetGameTimeMilliseconds() - currentfight.combatend >= 50)) then return end				-- only record in combat, don't record pet incoming heal
	
	CombatEventHandler(true, ...)	-- (isheal, ...)
end

local function onCombatEventHealIn(...)
	-- avoid counting actions to oneself twice
	local _, _, _, _, _, _, _, sourceType, _, targetType , _, _, _, _, _, _, _ = ...
	
	if (sourceType == COMBAT_UNIT_TYPE_PLAYER or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET) and (targetType == COMBAT_UNIT_TYPE_PLAYER or targetType == COMBAT_UNIT_TYPE_PLAYER_PET) then return end
	
	onCombatEventHeal(...)	-- (isheal, ...)
end

local function onCombatEventDmgGrp(_ , _ , _ , _ , _ , _ , _ , _ , targetName, targetType, hitValue, _ , _ , _ , _, targetUnitId, abilityId)  -- called by Event
	
	if hitValue < 2 or targetUnitId == nil or targetType==2 then return end
	
	if hitValue > 150000 then
	
		if dev then df("[%.3f] (%d) %s did %d damage to %s", GetGameTimeMilliseconds(), abilityId, GetFormattedAbilityName(abilityId), hitValue, tostring(targetName)) end
	
		return
	
	end
	
	local name = zo_strformat(SI_UNIT_NAME,(targetName or ""))
	
	table.insert(currentfight.grplog,{targetUnitId,hitValue,"dmg"})
end

local function onCombatEventHealGrp(_ , _ , _ , _ , _ , _ , _, _, _, targetType, hitValue, _, _, _, _, targetUnitId, _)  -- called by Event
	
	if targetType==2 or targetUnitId == nil or targetName == "" or hitValue<2 or (data.inCombat == false and (GetGameTimeMilliseconds() - (currentfight.combatend or 0) >= 50)) then return end
	
	local name = zo_strformat(SI_UNIT_NAME,(targetName or ""))
	
	table.insert(currentfight.grplog,{targetUnitId,hitValue,"heal"})
end

local lastCastTimeAbility = 0

local function GetReducedSlotId(reducedslot)

	local bar = reducedslot > 10 and 2 or 1

	local slot = reducedslot%10
	
	local origId = (data.skillBars and data.skillBars[bar] and data.skillBars[bar][slot]) or nil

	return origId
	
end
	
local function onAbilityUsed(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId) 

	if Events.Skills.active ~= true or validSkillStartResults[result] ~= true then return end
	
	local lasttime = lastskilluses[abilityId] or 0
	
	local timems = GetGameTimeMilliseconds()
	
	if timems - lasttime > 2000 then return end
	
	lastskilluses[abilityId] = nil	
	
	local reducedslot = IdToReducedSlot[abilityId]
	
	local origId = GetReducedSlotId(reducedslot)
	
	local channeled, castTime, channelTime = GetAbilityCastInfo(origId)
	
	castTime = channeled and channelTime or castTime
	
	-- if dev == true then df("[%.3f] Skill used: %s (%d), Duration: %ds Target: %s", timems/1000, GetAbilityName(abilityId), abilityId, castTime/1000, tostring(target)) end
	
	if castTime > 0 then
	
		abilityId = abilityConversions[abilityId] or abilityId
		
		local status = channeled and LIBCOMBAT_SKILLSTATUS_BEGIN_CHANNEL or LIBCOMBAT_SKILLSTATUS_BEGIN_DURATION
		
		lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_SKILL_TIMINGS), LIBCOMBAT_EVENT_SKILL_TIMINGS, timems, reducedslot, abilityId, status)
		
		if abilityId == -1 then 
		
			local function delayedsuccess()
			
				local data = {reducedslot, abilityId, LIBCOMBAT_SKILLSTATUS_SUCCESS}
			
				lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_SKILL_TIMINGS), LIBCOMBAT_EVENT_SKILL_TIMINGS, GetGameTimeMilliseconds(), unpack(data))
			
			end
			
			zo_callLater(delayedsuccess, castTime)
			
		else
	
			lastCastTimeAbility = abilityId
			
		end
	
	else
	
		lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_SKILL_TIMINGS), LIBCOMBAT_EVENT_SKILL_TIMINGS, timems, reducedslot, abilityId, LIBCOMBAT_SKILLSTATUS_INSTANT)
		lastCastTimeAbility = 0
		
	end
end

local function onAbilityFinished(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId) 
	
	if validSkillEndResults[result] ~= true then return end
	
	local timems = GetGameTimeMilliseconds()
	
	local reducedslot = IdToReducedSlot[abilityId]	
	
	if abilityId == lastCastTimeAbility then

		local timems = GetGameTimeMilliseconds()
		
		-- if dev == true then df("[%.3f] Skill activated: %s (%d, R: %d)", GetGameTimeMilliseconds()/1000, GetAbilityName(abilityId), abilityId, result) end
		
		lib.cm:FireCallbacks(("LibCombat"..LIBCOMBAT_EVENT_SKILL_TIMINGS), LIBCOMBAT_EVENT_SKILL_TIMINGS, timems, reducedslot, abilityId, LIBCOMBAT_SKILLSTATUS_SUCCESS)
		
		lastCastTimeAbility = 0
		
	end
end

local function UpdateEventRegistrations()

	for _,Eventgroup in pairs(Events) do
	
		Eventgroup:UpdateEvents()
		
	end
	
end

local function EditResource(callbacktype,add,name)

	if add == true then 
	
		ActiveCallbackTypes[callbacktype][name] = true
	
	elseif add == false then
		
		ActiveCallbackTypes[callbacktype][name] = nil
	
	end
	
	UpdateEventRegistrations()
end

local function InitResources()

	for i=LIBCOMBAT_EVENT_MIN,LIBCOMBAT_EVENT_MAX do
	
		ActiveCallbackTypes[i]={}
		
	end
end

function lib:RegisterAllLogCallbacks(callback, name)

	for i=LIBCOMBAT_EVENT_DAMAGE_OUT,LIBCOMBAT_EVENT_MAX do
	
		lib:RegisterCallbackType(i,callback,name)
		
	end
end

function lib:RegisterCallbackType(callbacktype, callback, name)

	lib.cm:RegisterCallback("LibCombat"..callbacktype, callback)
	EditResource(callbacktype,true,name)
	
end

function lib:UnregisterCallbackType(callbacktype, callback, name)
	
	lib.cm:UnregisterCallback("LibCombat"..callbacktype, callback)
	EditResource(callbacktype,false,name)
	
end

function lib:GetCurrentFight()

	local copy = {}
	
	if currentfight.dpsstart ~= nil then
	
		ZO_DeepTableCopy(currentfight, copy)
		
	else 
	
		copy = nil
		
	end
	
	return copy
end

local EventHandler = ZO_Object:Subclass()

function EventHandler:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

function EventHandler:Initialize(callbacktypes,regfunc)

	self.data={}
	self.callbacktypes=callbacktypes
	self.active=false
	self.RegisterEvents = regfunc
	
end

function EventHandler:RegisterEvent(event, callback, ...) -- convinience function

	local filters = {...}
	
	lib.totalevents = (lib.totalevents or 0) + 1
	
	local active = EVENT_MANAGER:RegisterForEvent(lib.name..lib.totalevents, event, callback)
	local filtered = false
	
	if #filters>0 and (#filters)%2==0 then 
		
		filtered = EVENT_MANAGER:AddFilterForEvent(lib.name..lib.totalevents, event, unpack(filters))
	
	end
	
	self.data[#self.data+1] = { ["id"]=lib.totalevents, ["event"] = event, ["callback"] = callback, ["active"] = active, ["filtered"] = filtered , ["filters"] = filters }  -- remove callbacks later, probably not necessary
	
	if active then lib.totalevents = lib.totalevents + 1 end
end

function EventHandler:UpdateEvents()

	local condition = false
	
	for k,v in pairs(self.callbacktypes) do
		
		if NonContiguousCount(ActiveCallbackTypes[v])>0 then condition = true break end
	
	end
	
	if condition == true and self.active == false then 
		
		self:RegisterEvents() 
	
	elseif condition == false and self.active == true then
		
		self:UnregisterEvents()
	end
	
end

function EventHandler:UnregisterEvents()

	for k,reg in pairs(self.data) do
		
		local incative = EVENT_MANAGER:UnregisterForEvent(lib.name..reg.id, reg.event)
		
		if incative then 
		
			ZO_ClearTable(reg)
			self.data[k] = nil 
			
		end
	end
	
	self.active = false
end

lib.Events = Events		-- debug exposure

local function UnregisterAllEvents()

	for _,Eventgroup in pairs(Events) do
		Eventgroup:UnregisterEvents()
	end
end

--  lib.UnregisterAllEvents = UnregisterAllEvents 	-- debug exposure

local function GetAllCallbackTypes()
	local t={}
	for i=LIBCOMBAT_EVENT_MIN,LIBCOMBAT_EVENT_MAX do
		t[i]=i
	end
	return t
end


Events.General = EventHandler:New(GetAllCallbackTypes()
	,
	function (self)
		self:RegisterEvent(EVENT_PLAYER_COMBAT_STATE, onCombatState)
		self:RegisterEvent(EVENT_UNIT_CREATED, onGroupChange)
		self:RegisterEvent(EVENT_UNIT_DESTROYED, onGroupChange)
		self:RegisterEvent(EVENT_ACTION_SLOT_ABILITY_SLOTTED, GetCurrentSkillBars)
		self:RegisterEvent(EVENT_PLAYER_ACTIVATED, onPlayerActivated)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onMageExplode, REGISTER_FILTER_ABILITY_ID, 50184)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onShadowWorld, REGISTER_FILTER_ABILITY_ID, 108045)
		
		if showdebug == true then self:RegisterEvent(EVENT_COMBAT_EVENT, onCustomEvent, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_IS_ERROR, false) end		
		self.active = true
	end
)

Events.DmgOut = EventHandler:New(
	{LIBCOMBAT_EVENT_FIGHTRECAP, LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_EVENT_DAMAGE_OUT, LIBCOMBAT_EVENT_DAMAGE_SELF},
	function (self)
		self:RegisterEvent(EVENT_BOSSES_CHANGED, onBossesChanged)
		local filters = {
			ACTION_RESULT_DAMAGE,
			ACTION_RESULT_DOT_TICK,		
			ACTION_RESULT_BLOCKED_DAMAGE,
			ACTION_RESULT_DAMAGE_SHIELDED,
			ACTION_RESULT_CRITICAL_DAMAGE,	
			ACTION_RESULT_DOT_TICK_CRITICAL,		
		}
		for i=1,#filters do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventDmg, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, 		REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventDmg, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET, 	REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
		end
		self.active = true
	end
)

Events.DmgIn = EventHandler:New(
	{LIBCOMBAT_EVENT_FIGHTRECAP, LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_EVENT_DAMAGE_IN},
	function (self)
		self:RegisterEvent(EVENT_BOSSES_CHANGED, onBossesChanged)
		local filters = {
			ACTION_RESULT_DAMAGE,
			ACTION_RESULT_DOT_TICK,		
			ACTION_RESULT_BLOCKED_DAMAGE,
			ACTION_RESULT_DAMAGE_SHIELDED,
			ACTION_RESULT_CRITICAL_DAMAGE,	
			ACTION_RESULT_DOT_TICK_CRITICAL,		
		}
		for i=1,#filters do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventDmgIn, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, 		REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventDmgIn, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET, 	REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
		end
		self.active = true
	end
)

Events.HealOut = EventHandler:New(
	{LIBCOMBAT_EVENT_FIGHTRECAP, LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_EVENT_HEAL_OUT, LIBCOMBAT_EVENT_HEAL_SELF},
	function (self)
		self:RegisterEvent(EVENT_BOSSES_CHANGED, onBossesChanged)
		local filters = {
			ACTION_RESULT_HOT_TICK,
			ACTION_RESULT_HEAL,
			ACTION_RESULT_CRITICAL_HEAL,
			ACTION_RESULT_HOT_TICK_CRITICAL,	
		}
		for i=1,#filters do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventHeal, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, 	REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventHeal, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET, REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
		end
		self.active = true
	end
)

Events.HealIn = EventHandler:New(
	{LIBCOMBAT_EVENT_FIGHTRECAP, LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_EVENT_HEAL_IN},
	function (self)
		self:RegisterEvent(EVENT_BOSSES_CHANGED, onBossesChanged)
		local filters = {
			ACTION_RESULT_HOT_TICK,
			ACTION_RESULT_HEAL,
			ACTION_RESULT_CRITICAL_HEAL,
			ACTION_RESULT_HOT_TICK_CRITICAL,	
		}
		for i=1,#filters do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventHealIn, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, 		REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onCombatEventHealIn, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET, 	REGISTER_FILTER_COMBAT_RESULT , filters[i], REGISTER_FILTER_IS_ERROR, false)
		end
		self.active = true
	end
)

Events.CombatGrp = EventHandler:New(
	{LIBCOMBAT_EVENT_GROUPRECAP},
	function (self)
		local filters = {
			[onCombatEventDmgGrp] = {
				ACTION_RESULT_DAMAGE,
				ACTION_RESULT_DOT_TICK,		
				ACTION_RESULT_BLOCKED_DAMAGE,
				ACTION_RESULT_DAMAGE_SHIELDED,
				ACTION_RESULT_CRITICAL_DAMAGE,	
				ACTION_RESULT_DOT_TICK_CRITICAL,
			},
			[onCombatEventHealGrp] = {
				ACTION_RESULT_HOT_TICK,
				ACTION_RESULT_HEAL,
				ACTION_RESULT_CRITICAL_HEAL,
				ACTION_RESULT_HOT_TICK_CRITICAL,
			},
		}
		for k,v in pairs(filters) do
			for i=1, #v do
				self:RegisterEvent(EVENT_COMBAT_EVENT, k, REGISTER_FILTER_COMBAT_RESULT , v[i], REGISTER_FILTER_IS_ERROR, false)
			end	
		end
		self.active = true
	end
)

Events.Effects = EventHandler:New(
	{LIBCOMBAT_EVENT_EFFECTS_IN,LIBCOMBAT_EVENT_EFFECTS_OUT,LIBCOMBAT_EVENT_GROUPEFFECTS_IN,LIBCOMBAT_EVENT_GROUPEFFECTS_OUT},
	function (self)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER_PET)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_NONE)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_TARGET_DUMMY)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onEffectChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_OTHER)
		
		for i=1,#SpecialBuffs do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialBuffEvent, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_ABILITY_ID, SpecialBuffs[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialBuffEvent, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED, REGISTER_FILTER_ABILITY_ID, SpecialBuffs[i], REGISTER_FILTER_IS_ERROR, false)
			
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialBuffEventNoSelf, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_ABILITY_ID, SpecialBuffs[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialBuffEventNoSelf, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED, REGISTER_FILTER_ABILITY_ID, SpecialBuffs[i], REGISTER_FILTER_IS_ERROR, false)
		end
		
		for i=1,#SpecialDebuffs do
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialDebuffEvent, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_ABILITY_ID, SpecialDebuffs[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialDebuffEvent, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED, REGISTER_FILTER_ABILITY_ID, SpecialDebuffs[i], REGISTER_FILTER_IS_ERROR, false)
			
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialDebuffEventNoSelf, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_GAINED_DURATION, REGISTER_FILTER_ABILITY_ID, SpecialDebuffs[i], REGISTER_FILTER_IS_ERROR, false)
			self:RegisterEvent(EVENT_COMBAT_EVENT, onSpecialDebuffEventNoSelf, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_EFFECT_FADED, REGISTER_FILTER_ABILITY_ID, SpecialDebuffs[i], REGISTER_FILTER_IS_ERROR, false)
		end
		self.active = true
	end
)

Events.GroupEffectsIn = EventHandler:New(
	{LIBCOMBAT_EVENT_GROUPEFFECTS_IN},
	function (self)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onGroupEffectIn, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
		self.active = true
	end
)

Events.GroupEffectsOut = EventHandler:New(
	{LIBCOMBAT_EVENT_GROUPEFFECTS_OUT},
	function (self)
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onGroupEffectOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP, REGISTER_FILTER_UNIT_TAG, "")
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onGroupEffectOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP, REGISTER_FILTER_UNIT_TAG, "reticleover")
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onGroupEffectOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP, REGISTER_FILTER_UNIT_TAG, "reticleoverplayer")
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onGroupEffectOut, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_GROUP, REGISTER_FILTER_UNIT_TAG_PREFIX, "boss")
		self.active = true
	end
)

Events.Stats = EventHandler:New(
	{LIBCOMBAT_EVENT_PLAYERSTATS},
	function (self)
		
		for id, _ in pairs(MajorForceAbility) do
			
			self:RegisterEvent(EVENT_EFFECT_CHANGED, onMajorForceChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, id)
		
		end	
		
		for id, _ in pairs(MinorForceAbility) do
			
			self:RegisterEvent(EVENT_EFFECT_CHANGED, onMinorForceChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, id)
		
		end	
		
		self:RegisterEvent(EVENT_EFFECT_CHANGED, onTFSChanged, REGISTER_FILTER_UNIT_TAG, "player", REGISTER_FILTER_ABILITY_ID, 51176)  -- to track TFS procs, which aren't recognized for stacks > 1 in penetration stat.
	end
)

Events.Resources = EventHandler:New(
	{LIBCOMBAT_EVENT_RESOURCES},
	function (self)
		self:RegisterEvent(EVENT_POWER_UPDATE, onBaseResourceChanged, REGISTER_FILTER_UNIT_TAG, "player")
		self:RegisterEvent(EVENT_COMBAT_EVENT, onResourceChanged, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_POWER_ENERGIZE, REGISTER_FILTER_IS_ERROR, false)
		self:RegisterEvent(EVENT_COMBAT_EVENT, onResourceChanged, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_POWER_DRAIN, REGISTER_FILTER_IS_ERROR, false)
		self.active = true
	end
)

Events.Messages = EventHandler:New(
	{LIBCOMBAT_EVENT_MESSAGES, LIBCOMBAT_EVENT_FIGHTSUMMARY, LIBCOMBAT_EVENT_SKILL_TIMINGS},
	function (self)
		self:RegisterEvent(EVENT_ACTION_SLOTS_FULL_UPDATE, onWeaponSwap)
		
		
		self.active = true
	end
)

Events.Deaths = EventHandler:New(
	{LIBCOMBAT_EVENT_DEATH},
	function (self)
		self:RegisterEvent(EVENT_COMBAT_EVENT, OnDeath, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_KILLING_BLOW)
		self:RegisterEvent(EVENT_COMBAT_EVENT, OnDeath, REGISTER_FILTER_COMBAT_RESULT, ACTION_RESULT_DIED)
		self:RegisterEvent(EVENT_UNIT_DEATH_STATE_CHANGED, OnDeathStateChanged, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
		self:RegisterEvent(EVENT_PLAYER_REINCARNATED, OnPlayerReincarnated)
		self.active = true
	end
)

Events.Resurrections = EventHandler:New(
	{LIBCOMBAT_EVENT_RESURRECTION},
	function (self)
		self:RegisterEvent(EVENT_RESURRECT_RESULT, OnResurrectResult)
		self:RegisterEvent(EVENT_RESURRECT_REQUEST , OnResurrectRequest)
		self.active = true
	end
)

Events.Slots = EventHandler:New(
	{LIBCOMBAT_EVENT_RESOURCES, LIBCOMBAT_EVENT_SKILL_TIMINGS},
	function (self)
		
		self:RegisterEvent(EVENT_ACTION_SLOT_ABILITY_USED , onSlotUpdate)
		
		self.active = true
	end
)

Events.Skills = EventHandler:New(
	{LIBCOMBAT_EVENT_SKILL_TIMINGS},	
	function (self)
		
		
		for _, skill in pairs(SlotSkills) do
		
			local id, result, finish = unpack(skill)
			
			local func = finish and onAbilityFinished or onAbilityUsed
			
			if result then 
			
				self:RegisterEvent(EVENT_COMBAT_EVENT, func, REGISTER_FILTER_ABILITY_ID, id, REGISTER_FILTER_COMBAT_RESULT, result)
			
			else
			
				self:RegisterEvent(EVENT_COMBAT_EVENT, func, REGISTER_FILTER_ABILITY_ID, id)
			
			end
		end
	
		self.active = true
		
	end
)

--Combat Log

local strings = {

	SI_LIBCOMBAT_LOG_CRITICAL = "critically ",  -- "critically"
	SI_LIBCOMBAT_LOG_YOU = "you", -- "you"
	SI_LIBCOMBAT_LOG_GAINED = "gained", -- "gained"
	SI_LIBCOMBAT_LOG_NOGAINED = "gained no", -- "gained no"
	SI_LIBCOMBAT_LOG_LOST = "lost", -- "lost"

	SI_LIBCOMBAT_LOG_UNITTYPE_PLAYER = "yourself", -- "You"
	SI_LIBCOMBAT_LOG_UNITTYPE_PET = "your pet", -- "Pet"
	SI_LIBCOMBAT_LOG_UNITTYPE_GROUP = "a group member", -- "Groupmember"
	SI_LIBCOMBAT_LOG_UNITTYPE_OTHER = "another Player", -- "Another Player"

	SI_LIBCOMBAT_LOG_IS_AT = "is at", -- "Weapon Swap"
	SI_LIBCOMBAT_LOG_INCREASED = "increased to", -- "Weapon Swap"
	SI_LIBCOMBAT_LOG_DECREASED = "decreased to", -- "Weapon Swap"

	SI_LIBCOMBAT_LOG_ULTIMATE = "Ultimate", -- "Weapon Swap"
	SI_LIBCOMBAT_LOG_BASEREG = "Base Regneration", -- "Weapon Swap"

	SI_LIBCOMBAT_LOG_STAT_SPELL_CRIT_DONE = "Spell Critical Damage",  -- "Spell Critical Damage"
	SI_LIBCOMBAT_LOG_STAT_WEAPON_CRIT_DONE = "Physical Critical Damage",  -- "Physical Critical Damage"
	
	SI_LIBCOMBAT_LOG_MESSAGE1 = "Entering Combat",  -- "Entering Combat"
	SI_LIBCOMBAT_LOG_MESSAGE2 = "Exiting Combat",  -- "Entering Combat"
	SI_LIBCOMBAT_LOG_MESSAGE3 = "Weapon Swap",  -- "Entering Combat"	
	SI_LIBCOMBAT_LOG_MESSAGE_BAR = "Bar",  -- "Entering Combat"	

	SI_LIBCOMBAT_LOG_FORMAT_TARGET_NORMAL = "%s|r with ",  -- i.e. "dwemer sphere with", %s = targetname. |r stops the colored text
	SI_LIBCOMBAT_LOG_FORMAT_TARGET_SHIELD = "%ss shield:|r",  -- i.e. "dwemer spheres shield:", %s = targetname. |r stops the colored text "
	SI_LIBCOMBAT_LOG_FORMAT_TARGET_BLOCK = "%ss block|r with",  -- i.e. "dwemer spheres block with", %s = targetname. |r stops the colored text 

	SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_NORMAL = "you|r with ",  -- i.e. "you with", |r stops the colored text
	SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_SELF = "yourself|r with ",  -- i.e. "you with", |r stops the colored text
	SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_SHIELD = "your shield:|r",  -- i.e. "your shield:", |r stops the colored text
	SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_BLOCK = "your block|r with",  -- i.e. "your block", |r stops the colored text

	SI_LIBCOMBAT_LOG_FORMATSTRING4 = "<<1>> |cffffffYou|r <<2>>hit |cffdddd<<3>> <<4>> for |cffffff<<5>>.",  	-- damage out, i.e. "[0.0s] You critically hit target with Light Attack for 1234.". <<1>> = timestring, <<2>> = crit,  <<3>> = targetstring,  <<4>> = ability, <<5>> = hitValue
	SI_LIBCOMBAT_LOG_FORMATSTRING5 = "<<1>> |cffdddd<<2>>|r <<3>>hits |cffffff<<4>> <<5>> for |cffffff<<6>>.",  -- damage in, i.e. "[0.0s] Someone critically hits you with Light Attack for 1234.". <<1>> = timestring, <<2>> = sourceName,  <<3>> = crit,  <<4>> = targetstring,  <<5>> = ability, <<6>> = hitValue
	SI_LIBCOMBAT_LOG_FORMATSTRING6 = "<<1>> |cffffffYou|r <<2>>hit |cffffff<<3>> <<4>> for |cffffff<<5>>.",  	-- damage self, i.e. "[0.0s] You critically hit yourself with Light Attack for 1234.". <<1>> = timestring, <<2>> = crit,  <<3>> = targetstring,  <<4>> = ability, <<5>> = hitValue

	SI_LIBCOMBAT_LOG_FORMATSTRING7 = "<<1>> |cffffffYou|r <<2>>heal |cddffdd<<3>>|r with <<4>> for |cffffff<<5>>.",  	-- healing out, i.e. "[0.0s] You critically heal target with Mutagen for 1234.". <<1>> = timestring, <<2>> = crit,  <<3>> = targetname,  <<4>> = ability, <<5>> = hitValue
	SI_LIBCOMBAT_LOG_FORMATSTRING8 = "<<1>> |cddffdd<<2>>|r <<3>>heals |cffffffyou|r with <<4>> for |cffffff<<5>>.",  	-- healing in, i.e. "[0.0s] Someone critically heals you with Mutagen for 1234.". <<1>> = timestring, <<2>> = sourceName, <<3>> = crit,  <<4>> = ability, <<5>> = hitValue
	SI_LIBCOMBAT_LOG_FORMATSTRING9 = "<<1>> |cffffffYou|r <<2>>heal |cffffffyourself|r with <<3>> for |cffffff<<4>>.",  -- healing self, i.e. "[0.0s] You critically heal yourself with Mutagen for 1234.". <<1>> = timestring, <<2>> = crit,  <<3>> = ability, <<4>> = hitValue

	SI_LIBCOMBAT_LOG_FORMATSTRING10 = "<<1>> |cffffff<<2>>|r <<3>> <<4>><<5>>.",  -- buff, i.e. "[0.0s] You gained Block from yourself." <<1>> = timestring, <<2>> = sourceName, <<3>> = changetype,  <<4>> = ability, <<5>> = source
	SI_LIBCOMBAT_LOG_FORMATSTRING11 = "<<1>> |cffffff<<2>>|r <<3>> <<4>><<5>>.",  -- buff, i.e. "[0.0s] You gained Block from yourself." <<1>> = timestring, <<2>> = sourceName, <<3>> = changetype,  <<4>> = ability, <<5>> = source
	SI_LIBCOMBAT_LOG_FORMATSTRING12 = "<<1>> |cffffff<<2>>|r <<3>> <<4>><<5>>.",  -- buff, i.e. "[0.0s] You gained Block from yourself." <<1>> = timestring, <<2>> = sourceName, <<3>> = changetype,  <<4>> = ability, <<5>> = source
	SI_LIBCOMBAT_LOG_FORMATSTRING13 = "<<1>> |cffffff<<2>>|r <<3>> <<4>><<5>>.",  -- buff, i.e. "[0.0s] You gained Block from yourself." <<1>> = timestring, <<2>> = sourceName, <<3>> = changetype,  <<4>> = ability, <<5>> = source

	SI_LIBCOMBAT_LOG_FORMATSTRING14 = "<<1>> Your <<2>> <<3>> |cffffff<<4>>|r<<5>>.",  -- buff, i.e. "[0.0s] Weaponpower increased to 1800 (+100)". <<1>> = timeString, <<2>> = stat, <<3>> = changeText,  <<4>> = value, <<5>> = changeValueText
	
	SI_LIBCOMBAT_LOG_FORMATSTRING15 = "<<1>> |cffffffYou|r <<2>>|r <<3>> <<4>> |cffffff(<<5>>)|r.",  -- buff, i.e. "[0.0s] You gained 200 Magicka (Base Regeneration,." <<1>> = timeString, <<2>> = changeTypeString, <<3>> = amount,  <<4>> = resource, <<5>> = ability

	SI_LIBCOMBAT_LOG_FORMATSTRING_SKILLS1 = "<<1>> You cast <<2>>.", -- skill used, i.e. "[0.0s] You used Puncturing Sweeps. (<<1>> = timestring, <<2>> = Ability)
	SI_LIBCOMBAT_LOG_FORMATSTRING_SKILLS2 = "<<1>> You start to cast <<2>>.", -- skill used, i.e. "[0.0s] You start to cast Solar Barrage. (<<1>> = timestring, <<2>> = Ability)
	SI_LIBCOMBAT_LOG_FORMATSTRING_SKILLS3 = "<<1>> You start to channel <<2>>.", -- skill used, i.e. "[0.0s] You start to target Blazing Spear. (<<1>> = timestring, <<2>> = Ability)
	SI_LIBCOMBAT_LOG_FORMATSTRING_SKILLS4 = "<<1>> You finished casting <<2>>.", -- skill used, i.e. "[0.0s] You succeeded casting Blazing Spear. (<<1>> = timestring, <<2>> = Ability)
	
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end

local statnames = {
	["spellpower"]		= "|c8888ff"..GetString(SI_DERIVEDSTATS25).."|r ", 							--|c8888ff blue
	["spellcrit"]		= "|c8888ff"..GetString(SI_DERIVEDSTATS23).."|r ",
	["maxmagicka"]		= "|c8888ff"..GetString(SI_DERIVEDSTATS4).."|r ",
	["spellcritbonus"]	= "|c8888ff"..GetString(SI_LIBCOMBAT_LOG_STAT_SPELL_CRIT_DONE).."|r ",
	["spellpen"]		= "|c8888ff"..GetString(SI_DERIVEDSTATS34).."|r ",
		
	["weaponpower"]		= "|c88ff88"..GetString(SI_DERIVEDSTATS1).."|r ",			--|c88ff88 green
	["weaponcrit"]		= "|c88ff88"..GetString(SI_DERIVEDSTATS16).."|r ",
	["maxstamina"]		= "|c88ff88"..GetString(SI_DERIVEDSTATS29).."|r ",
	["weaponcritbonus"]	= "|c88ff88"..GetString(SI_LIBCOMBAT_LOG_STAT_WEAPON_CRIT_DONE).."|r ",
	["weaponpen"]		= "|c88ff88"..GetString(SI_DERIVEDSTATS33).."|r ",
	
	["maxhealth"]		= "|cffff88"..GetString(SI_DERIVEDSTATS7).."|r ",	--|cffff88 red
	["physres"]			= "|cffff88"..GetString(SI_DERIVEDSTATS22).."|r ",	--|cffff88 red
	["spellres"]		= "|cffff88"..GetString(SI_DERIVEDSTATS13).."|r ",
	["critres"]			= "|cffff88"..GetString(SI_DERIVEDSTATS24).."|r ",
}		

local logColors={ 
	[DAMAGE_TYPE_NONE] 		= "|cE6E6E6", 
	[DAMAGE_TYPE_GENERIC] 	= "|cE6E6E6", 
	[DAMAGE_TYPE_PHYSICAL] 	= "|cf4f2e8", 
	[DAMAGE_TYPE_FIRE] 		= "|cff6600", 
	[DAMAGE_TYPE_SHOCK] 	= "|cffff66", 
	[DAMAGE_TYPE_OBLIVION] 	= "|cd580ff", 
	[DAMAGE_TYPE_COLD] 		= "|cb3daff", 
	[DAMAGE_TYPE_EARTH] 	= "|cbfa57d", 
	[DAMAGE_TYPE_MAGIC] 	= "|c9999ff", 
	[DAMAGE_TYPE_DROWN] 	= "|ccccccc", 
	[DAMAGE_TYPE_DISEASE] 	= "|cc48a9f", 
	[DAMAGE_TYPE_POISON] 	= "|c9fb121", 
	["heal"]				= "|c55ff55",
	["buff"..BUFF_EFFECT_TYPE_BUFF]		= "|c00cc00",
	["buff"..BUFF_EFFECT_TYPE_DEBUFF]	= "|cff3333",
}

function lib.GetDamageColor(damageType)	
	return logColors[damageType]
end 

local function GetAbilityString(abilityId, damageType, fontsize)

	local icon = zo_iconFormat(GetFormattedAbilityIcon(abilityId), fontsize, fontsize)
	local name = GetFormattedAbilityName(abilityId)
	local damageColor = lib.GetDamageColor(damageType)
	
	return string.format("%s %s%s|r", icon, damageColor, name)
end

local UnitTypeString = {
	[COMBAT_UNIT_TYPE_PLAYER] 		= GetString(SI_LIBCOMBAT_LOG_UNITTYPE_PLAYER),
	[COMBAT_UNIT_TYPE_PLAYER_PET] 	= GetString(SI_LIBCOMBAT_LOG_UNITTYPE_PET),
	[COMBAT_UNIT_TYPE_GROUP] 		= GetString(SI_LIBCOMBAT_LOG_UNITTYPE_GROUP),
	[COMBAT_UNIT_TYPE_OTHER] 		= GetString(SI_LIBCOMBAT_LOG_UNITTYPE_OTHER),
}

function lib:GetCombatLogString(fight, logline, fontsize)
	
	if fight == nil then fight = currentfight end
	
	local logtype = logline[1]
	
	local color, text
	
	local timeValue = fight.combatstart < 0 and 0 or (logline[2] - fight.combatstart)/1000
	local timeString = string.format("|ccccccc[%.3fs]|r", timeValue)
	local stringFormat = logtype == LIBCOMBAT_EVENT_SKILL_TIMINGS and GetString("SI_LIBCOMBAT_LOG_FORMATSTRING_SKILLS", logline[5]) or GetString("SI_LIBCOMBAT_LOG_FORMATSTRING", logtype)
	
	local units = fight.units

	if logtype == LIBCOMBAT_EVENT_DAMAGE_OUT then 
	
		local _, _, result, _, targetUnitId, abilityId, hitValue, damageType = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_DAMAGE or result==ACTION_RESULT_DOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local targetname = units[targetUnitId].name
		local targetFormat = (result==ACTION_RESULT_DAMAGE_SHIELDED and SI_LIBCOMBAT_LOG_FORMAT_TARGET_SHIELD) or (result==ACTION_RESULT_BLOCKED_DAMAGE and SI_LIBCOMBAT_LOG_FORMAT_TARGET_BLOCK) or SI_LIBCOMBAT_LOG_FORMAT_TARGET_NORMAL
		
		local targetString = string.format(GetString(targetFormat), targetname)
		
		local ability = GetAbilityString(abilityId, damageType, fontsize)
		
		color = {1.0,0.6,0.6}
		text = zo_strformat(stringFormat, timeString, crit, targetString, ability, hitValue)
		
	elseif logtype == LIBCOMBAT_EVENT_DAMAGE_IN then
	
		local _, _, result, sourceUnitId, _, abilityId, hitValue, damageType = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local sourceName = units[sourceUnitId].name
		
		local targetFormat = (result==ACTION_RESULT_DAMAGE_SHIELDED and SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_SHIELD) or (result==ACTION_RESULT_BLOCKED_DAMAGE and SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_BLOCK) or SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_NORMAL
		local targetString = GetString(targetFormat)
		
		local ability = GetAbilityString(abilityId, damageType)
		
		color = {0.8,0.4,0.4}	
		
		text = zo_strformat(stringFormat, timeString, sourceName, crit, targetString, ability, hitValue)
				
	elseif logtype == LIBCOMBAT_EVENT_DAMAGE_SELF then
	
		local _, _, result, _, _, abilityId, hitValue, damageType = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local targetFormat = (result==ACTION_RESULT_DAMAGE_SHIELDED and SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_SHIELD) or (result==ACTION_RESULT_BLOCKED_DAMAGE and SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_BLOCK) or SI_LIBCOMBAT_LOG_FORMAT_TARGETSELF_SELF
		local targetString = GetString(targetFormat)
		
		local ability = GetAbilityString(abilityId, damageType, fontsize)
		
		color = {0.8,0.4,0.4}	
		text = zo_strformat(stringFormat, timeString, crit, targetString, ability, hitValue)
			
	elseif logtype == LIBCOMBAT_EVENT_HEAL_OUT then
		
		local _, _, result, _, targetUnitId, abilityId, hitValue, _ = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local targetname = units[targetUnitId].name

		local ability = GetAbilityString(abilityId, "heal", fontsize, fontsize)
		
		color = {0.6,1.0,0.6}
		text = zo_strformat(stringFormat, timeString, crit, targetname, ability, hitValue)
		
	elseif logtype == LIBCOMBAT_EVENT_HEAL_IN then
	
		local _, _, result, sourceUnitId, _, abilityId, hitValue, _ = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local sourceName = units[sourceUnitId].name
		
		local ability = GetAbilityString(abilityId, "heal", fontsize)
		
		color = {0.4,0.8,0.4}
		text = zo_strformat(stringFormat, timeString, sourceName, crit, ability, hitValue)
		
	elseif logtype == LIBCOMBAT_EVENT_HEAL_SELF then 
	
		local _, _, result, _, _, abilityId, hitValue, _ = unpack(logline)
		
		local crit = (result==ACTION_RESULT_CRITICAL_HEAL or result==ACTION_RESULT_HOT_TICK_CRITICAL) and "|cFFCC99"..GetString(SI_LIBCOMBAT_LOG_CRITICAL).."|r" or ""
		
		local ability = GetAbilityString(abilityId, "heal", fontsize)
		
		color = {0.8,1.0,0.6}		
		text = zo_strformat(stringFormat, timeString, crit, ability, hitValue)
		
	elseif logtype == LIBCOMBAT_EVENT_EFFECTS_IN or logtype == LIBCOMBAT_EVENT_EFFECTS_OUT  or logtype == LIBCOMBAT_EVENT_GROUPEFFECTS_IN  or logtype == LIBCOMBAT_EVENT_GROUPEFFECTS_OUT then 
	
		local _, _, unitId, abilityId, changeType, effectType, _, sourceType = unpack(logline)
		
		if units[unitId] == nil then return end
		
		local unitString = fight.playerid == unitId and GetString(SI_LIBCOMBAT_LOG_YOU) or units[unitId].name
		
		local changeTypeString = (changeType == EFFECT_RESULT_GAINED or changeType == EFFECT_RESULT_UPDATED) and GetString(SI_LIBCOMBAT_LOG_GAINED) or changeType == EFFECT_RESULT_FADED and GetString(SI_LIBCOMBAT_LOG_LOST) 

		local source = UnitTypeString[sourceType] == nil and "" or string.format(" from %s", UnitTypeString[sourceType])
		
		local buff = GetAbilityString(abilityId, "buff"..effectType, fontsize)
		
		color = {0.8,0.8,0.8}
		text = zo_strformat(stringFormat, timeString, unitString, changeTypeString, buff, source)
		
	elseif logtype == LIBCOMBAT_EVENT_RESOURCES then 
	
		local _, _, abilityId, powerValueChange, powerType = unpack(logline)
		
		if powerValueChange ~= nil then 
		
			local source = "|cffffffYou |r"
			
			local changeTypeString = 
				(powerValueChange > 0 and "|c00cc00"..GetString(SI_LIBCOMBAT_LOG_GAINED))
				or (powerValueChange==0 and "|cffffff"..GetString(SI_LIBCOMBAT_LOG_NOGAINED)) 
				or "|cff3333"..GetString(SI_LIBCOMBAT_LOG_LOST) 
			
			local amount = powerValueChange~=0 and tostring(math.abs(powerValueChange)).."|r" or "|r"
			
			local resource = (powerType == POWERTYPE_MAGICKA and GetString(SI_ATTRIBUTES2)) or (powerType == POWERTYPE_STAMINA and GetString(SI_ATTRIBUTES3)) or (powerType == POWERTYPE_ULTIMATE and GetString(SI_LIBCOMBAT_LOG_ULTIMATE))
			
			local ability = abilityId and abilityId ~= 0 and GetFormattedAbilityName(abilityId) or GetString(SI_LIBCOMBAT_LOG_BASEREG)
			
			color = (powerType == POWERTYPE_MAGICKA and {0.7,0.7,1}) or (powerType == POWERTYPE_STAMINA and {0.7,1,0.7}) or (powerType == POWERTYPE_ULTIMATE and {1,1,0.7})
			text = zo_strformat(stringFormat, timeString, changeTypeString, amount, resource, ability)
		
		else return
		end

	elseif logtype == LIBCOMBAT_EVENT_PLAYERSTATS then 
	
		local _, _, statchange, newvalue, statname = unpack(logline)
		
		local stat = statnames[statname]
		local percent = ""
		local change = statchange
		local value = newvalue
		
		if statname=="spellcrit"or statname=="weaponcrit" then 
		
			value = string.format("%.1f%%", GetCriticalStrikeChance(newvalue))
			change = string.format("%.1f%%", GetCriticalStrikeChance(statchange))
			
		end
		
		if statname=="spellcritbonus" or statname=="weaponcritbonus" then 
		
			value = string.format("%.1f%%", newvalue)
			change = string.format("%.1f%%", statchange)
			
		end
		
		local changeText, changeValueText
		
		if statchange > 0 then

			changeText = "|c00cc00"..GetString(SI_LIBCOMBAT_LOG_INCREASED).."|r"
			changeValueText = " |c00cc00(+"..change..")|r"
			
		elseif statchange < 0 then
			
			changeText = "|cff3333"..GetString(SI_LIBCOMBAT_LOG_DECREASED).."|r"
			changeValueText = " |cff3333("..change..")|r"
			
		else 
		
			changeText = GetString(SI_LIBCOMBAT_LOG_IS_AT)
			changeValueText = ""
			
		end
		
		color = {0.8,0.8,0.8}
		text = zo_strformat(stringFormat, timeString, stat, changeText, value, changeValueText)

	elseif logtype == LIBCOMBAT_EVENT_MESSAGES then 
	
		local message = logline[3]
		local bar = logline[4]
		local messagetext		
		
		if message == LIBCOMBAT_MESSAGE_WEAPONSWAP then 
		
			color = {.6,.6,.6}
			local formatstring = bar ~= nil and bar > 0 and "%s (%s %d)" or "%s"

			messagetext = string.format(formatstring, GetString(SI_LIBCOMBAT_LOG_MESSAGE3), GetString(SI_LIBCOMBAT_LOG_MESSAGE_BAR), bar)
			
		elseif message ~= nil then 
		
			color = {.7,.7,.7}
			messagetext = type(message) == "number" and GetString("SI_LIBCOMBAT_LOG_MESSAGE", message) or message
			
		else return end
		
		text = zo_strformat("<<1>> <<2>>", timeString, messagetext)
	
	elseif logtype == LIBCOMBAT_EVENT_SKILL_TIMINGS then
	
		local _, _, reducedslot, abilityId, status = unpack(logline)
		
		local isWeaponAttack = reducedslot == 1 or reducedslot == 2 or reducedslot == 11 or reducedslot == 12		
		
		local name = GetFormattedAbilityName(abilityId)		
		
		if isWeaponAttack then name = " |cffffff"..name.."|r" end
		
		color = {.9,.8,.7}
		
		text = zo_strformat(stringFormat, timeString, name)
		
	end

	return text, color
end

local function Initialize() 
  
  data.inCombat = IsUnitInCombat("player")
  data.inGroup = IsUnitGrouped("player")
  data.playername = zo_strformat(SI_UNIT_NAME,GetUnitName("player"))
  data.accountname = GetDisplayName()
  data.bosses=0
  data.groupmembers={}
  data.groupmemberdisplaynames={}
  data.PlayerPets={}
  data.lastabilities = {}
  data.bossnames={}  
  data.majorForce = 0
  data.minorForce = 0
  data.critBonusMundus = 0
  data.bar = GetActiveWeaponPairInfo()
  
  --resetfightdata
  currentfight = FightHandler:New()
  
  InitResources()

  -- make addon options menu
  
  data.CustomAbilityIcon = {}
  data.CustomAbilityName = {
	[46539]	= "Major Force",
  }
  
  onBossesChanged()

  if data.LoadCustomizations then data.LoadCustomizations() end
  
  maxcrit = math.floor(100/GetCriticalStrikeChance(1))
end

Initialize()