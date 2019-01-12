local em = GetEventManager()
local _
local db
local newanchor
local active
local tlw
local sep
local SetRole
local ShowItems
local ClearItems
local SetDebug
local currentdata = {}
local dx = 1/GetSetting(SETTING_TYPE_UI, UI_SETTING_CUSTOM_SCALE) --Get UI Scale to draw thin lines correctly
UI_SCALE = dx
local activelyHidden = false

-- Addon Namespace
GDS = GDS or {}
GDS.name 		= "GroupDamageShare"
local addonVersion 	= "0.2.14"

local function Print(message, ...)

	if db.debug then df("[%s] %s", GDS.name, message:format(...)) end

end

local function spairs(t, order) -- from https://stackoverflow.com/questions/15706270/sort-a-table-in-lua

    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    if order then
	
        table.sort(keys, function(a,b) return order(t, a, b) end)
    
	else
    
		table.sort(keys)
    
	end

    local i = 0
	
    return function()
        i = i + 1
		
        if keys[i] then
		
            return keys[i], t[keys[i]]
			
        end
    end
end

local pool = ZO_ObjectPool:New(
		
	function(objectPool)
		
		return ZO_ObjectPool_CreateNamedControl("$(parent)UnitItem", "GROUPDAMAGESHARE_UnitItemTemplate", objectPool, tlw)
	
	end,
	
	function(olditem, objectPool)  -- Removes an item from the taunt list and redirect the anchors. 
		
		local key = olditem.key
		
		if key == nil then return end
		
		olditem:SetHidden(true)
		olditem:ClearAnchors()	
		
	end)

local classIconTex = {}

for i = 1, GetNumClasses() do

	local id, _, _, _, _, _, icontex, _, _, _ = GetClassInfo(i)
	
	classIconTex[id] = icontex
	
end

local function GetGrowthAnchor(item)
	
	local anchor = {TOPLEFT, item, BOTTOMLEFT, 0, 2}
	
	if item == nil then anchor = {TOPLEFT, tlw:GetNamedChild("Sep"), BOTTOMLEFT, 0, 4} end
	
	return anchor
end

local function AddSeparator()
	
	sep:SetHidden(false)
	sep:SetAnchor(unpack(newanchor))
	sep:SetThickness(dx)
	
	newanchor[1] = TOPRIGHT
	newanchor[3] = BOTTOMRIGHT
	newanchor[4] = -4
	
	sep:SetAnchor(unpack(newanchor))
	
	newanchor = GetGrowthAnchor(sep)
	newanchor[5] = newanchor[5] + 2 + dx

end
	
local function NewItem(unitTag, unitData, maxvalue, maxtime, heal)  -- Adds an item to the list,
	
	local alpha = unitData.isSelf and 1 or 0.7
	
	local item, key = pool:AcquireObject()
	
	item.key = key
	
	local barsize1 = (unitData.value or 1) / (maxvalue or 1) * db.window.width
	local barsize2 = (unitData.dpstime or 1) / (maxtime or 1) * db.window.width * 0.4
	
	local iconcolor
	
	local classId = unitData.class
	
	if classId > 16 then	-- classId holds info for the used class and the main resource (magicka / stamina). If larger then 16 prefered source is not known
	
		iconcolor = {1,1,1,1} -- white
		classId = classId - 16
		
	elseif classId > 8 then	-- magicka
	
		iconcolor = {0.6,0.6,1,1} -- blue
		classId = classId - 8
		
	else 	-- stamina
	
		iconcolor = {0.6,1,0.6,1} -- green
		
	end
	
	item:SetHidden(false)
	item:SetAnchor(unpack(newanchor))
	
	local font = ZO_CachedStrFormat("<<1>>|<<2>>|<<3>>", "EsoUI/Common/Fonts/Univers57.otf", db.window.height - (3 * dx), "soft-shadow-thin")
	
	local unitName = db.useAccountNames and GetDisplayName(unitTag) or ZO_CachedStrFormat(SI_UNIT_NAME, GetUnitName(unitTag))
	
	if unitName == "" then unitName = unitData.name end
	
	local label = item:GetNamedChild("Label")
	local icon = item:GetNamedChild("Icon")
	local bg = item:GetNamedChild("Bg")
	local bg2 = item:GetNamedChild("Bg2")
	local bar = item:GetNamedChild("Bar")
	local bar2 = item:GetNamedChild("Bar2")
	local value = item:GetNamedChild("Value")
	local timevalue = item:GetNamedChild("Time")
	
	label:SetText(unitName)
	label:SetFont(font)
	
	local width = db.window.width	
	local height = db.window.height	
	local icontex = classIconTex[classId]
	
	icon:SetDimensions(height, height)
	icon:SetTexture(icontex)
	icon:SetColor(unpack(iconcolor))
	
	bg:SetEdgeTexture("", 1, 1, 1)
	bg:SetDimensions(width, height)
	
	bg2:SetEdgeTexture("", 1, 1, 1)
	bg2:SetDimensions(width * 0.4, height)
	
	local barcolor = heal and db.color3 or db.color
	
	bar:SetDimensions(barsize1, height)
	bar:SetColor(barcolor.r, barcolor.g, barcolor.b, alpha)
	
	local barcolor2 = db.color2
	
	bar2:SetDimensions(barsize2,db.window.height)
	bar2:SetColor(barcolor2.r, barcolor2.g, barcolor2.b, alpha)
	
	value:SetHeight(height)
	value:SetFont(font)
	value:SetText(unitData.value or 1000)	
	
	timevalue:SetHeight(height)
	timevalue:SetFont(font)
	timevalue:SetText((unitData.dpstime or 10) .. " s")
	
	newanchor = GetGrowthAnchor(item)  -- new anchor for the next item 

	return key
end

local function Toggle(show)

	if show == nil then show = tlw:IsHidden() end
	
	tlw:SetHidden(not show)
	
end

function GDS_Slash(extra)

	local show  = tlw:IsHidden()
	
	activelyHidden = (not show)
	
	Toggle(show)
	
end

local function onGroupChange()

	local isGrouped = IsUnitGrouped("player")

	if db.onlyshowingroup and (not activelyHidden) then Toggle(isGrouped) end
	
	if isGrouped == false then activelyHidden = false end
	
end

function GDS_Hide()

	activelyHidden = true
	Toggle(false)
	
end

function GDS_Selector(button)

	local page = currentdata.page
	
	if button == 1 or button == -1 then 
	
		page = page + button
		
	elseif button == "end" then 
	
		page = 1
		
	end
	
	page = math.max(math.min(math.min(db.maxsavedfights, #currentdata.lastfights), page), 1)
	
	currentdata.page = page
	OnUIUpdate()
	
	Print("Current Page: %s", page)
end

function GDS_Switch(isHealer)
	
	if isHealer == nil then -- use argument or toggle
	
		isHealer = not db.isHealer
		
	end 

	SetRole(isHealer)
	
	local texture = db.isHealer and "esoui/art/lfg/lfg_healer_down_64.dds" or "esoui/art/lfg/lfg_dps_down_64.dds"
	
	tlw:GetNamedChild("SelectRole"):SetTexture(texture)
	
	OnUIUpdate()
	
end

-- EVENT_EFFECT_CHANGED ( eventCode,  changeType,  effectSlot,  effectName,  unitTag,  beginTime,  endTime,  stackCount,  iconName,  buffType,  effectType,  abilityType,  statusEffectType,  unitName,  unitId,  abilityId) 

function OnUpdate(unitTag, value, isHeal, dpstime, isSelf, class)

	local unit = currentdata.currentfight.units[unitTag] or {}
	
	unit.isHeal = isHeal
	unit.value = value
	unit.isSelf = isSelf
	unit.class = class
	
	if dpstime and dpstime > 0 then unit.dpstime = dpstime end
	
	currentdata.page = 0
	
	if(not active and IsUnitGrouped("player")) then
	
		EVENT_MANAGER:RegisterForUpdate(GDS.name.."LiveUpdate", db.updatetime, OnUIUpdate)
		active = true
		
	end
	
	currentdata.lastUpdate = GetTimeStamp()
end

local function DrawBars(isHeal, maxBars)

	if data == nil or data.units == nil then return end
	
	local maxvalue = 1
	local maxtime = 1
	
	local units = data.units

	local drawnBars = 0
	
	for unitTag, unit in pairs(units) do 
	
		if unit.isHeal == isHeal then
		
			maxvalue = math.max(unit.value, maxvalue)
			maxtime = math.max(unit.dpstime or 0, maxtime)
			
		end
		
	end	
	
	for unitTag, unit in spairs(units, function(t,a,b) return t[a]["value"] > t[b]["value"] end) do 
	
		if unit.isHeal == isHeal then
		
			NewItem(unitTag, unit, maxvalue, maxtime, false)
			
		end
	end
	
	if drawnBars >= maxBars then return end 
end

function OnUIUpdate()

	local data = (currentdata.page == 0 and currentdata.currentfight) or currentdata.lastfights[currentdata.page]
	
	pool:ReleaseAllObjects()
	newanchor = GetGrowthAnchor()
	
	local maxbarsDPS = db.maxItemsDPS
	local maxbarsHeal = db.maxItemsHeal	
	
	if maxbarsDPS > 0 then DrawBars(false, maxBars) end
	
	if maxbarsDPS > 0 and maxbarsHeal > 0 then AddSeparator() else sep:SetHidden(true) end
	
	if maxbarsHeal > 0 then DrawBars(true, maxBars) end
	
	tlw:GetNamedChild("Label"):SetText(data.time)
	
	if (GetTimeStamp() - currentdata.lastUpdate) > 3 then 
	
		if active then
		
			Print("Stop Update")
			EVENT_MANAGER:UnregisterForUpdate(GDS.name.."LiveUpdate")
			active = false
			
		end
		
	end
end

function onCombatStart()

	--if IsUnitDead("player") then return end
	
	Print("Combat Start")
	
	currentdata.page = 0
	
	currentdata.currentfight = {units = {}}
	
	currentdata.currentfight.time = GetDateStringFromTimestamp(GetTimeStamp())..", "..GetTimeString()
	
	pool:ReleaseAllObjects()
	newanchor = GetGrowthAnchor()
	
end

local function SaveData(data)

	local savedData = currentdata.lastfights
	
	table.insert(savedData,1,data)
	
	if #savedData > db.maxsavedfights then table.remove(savedData) end
	
end

function onCombatEnd()

	if currentdata.inCombat or SCENE_MANAGER:IsShowingNext("GROUPDAMAGESHARE_MOVE_SCENE") then return end
	
	Print("Combat End")
	
	SaveData(currentdata.currentfight)
	currentdata.page = 1
end

function onCombatState(event, inCombat)
	
	if currentdata.inCombat == inCombat then return end
	
	currentdata.inCombat = inCombat
	
	if inCombat == false then 
	
		zo_callLater(onCombatEnd, 1000) 
		
	elseif inCombat == true then
	
		onCombatStart()
		
	end 
end

local defaults = {
	["window"] = {
	
		x = 150 * dx,
		y = 150 * dx,
		height = zo_round(20 / dx) * dx,
		width = zo_round(240 / dx) * dx
		
	},	
	["locked"] = false,
	["isHealer"] = false,
	["updatetime"] = 250,
	["maxsavedfights"] = 15,
	["maxItemsDPS"] = 6,
	["maxItemsHeal"] = 3,
	["debug"] = false,
	["color"] = {r = 0.8, b = 0, g = 0},
	["color2"] = {r = 0.8, b = 0, g = 0.8},
	["color3"] = {r = 0, b = 0, g = 0.8},
	["bgalpha"] = 1,
	["accountwide"] = false,
	["onlyshowingroup"] = true,	
	["useAccountNames"] = false,	
}

local function MakeMenu()
    -- load the settings->addons menu library
	local menu = LibStub("LibAddonMenu-2.0")
	local def = defaults 

    -- the panel for the addons menu
	local panel = {
		type = "panel",
		name = "Group Damage Share",
		displayName = "GroupDamageShare",
		author = "Solinur",
        version = addonVersion or "",
		registerForRefresh = true,
	}
	
	GDS_PANEL = panel
	
	local addonpanel = menu:RegisterAddonPanel("GROUPDAMAGESHARE_OPTIONS", panel)
	
    --this adds entries in the addon menu
	local options = {		
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_AW_NAME),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_AW_TOOLTIP),
			default = def.accountwide,
			getFunc = function() return GroupDamageShare_Save.Default[GetDisplayName()]['$AccountWide']["accountwide"] end,
			setFunc = function(value) GroupDamageShare_Save.Default[GetDisplayName()]['$AccountWide']["accountwide"] = value end,
			requiresReload = true,
		},
		{
			type = "header",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_APPEARANCE),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_LOCK),
			tooltip = GetString(SI_GROUPDAMAGESHARE_LOCK_TOOLTIP),
			default = def.locked,
			getFunc = function() return db.locked end,
			setFunc = function(value) 
						db.locked = value; 
						tlw:SetMovable(not value)
					  end,
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWACCOUNTNAMES),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWACCOUNTNAMES_TOOLTIP),
			default = def.useAccountNames,
			getFunc = function() return db.useAccountNames end,
			setFunc = function(value) 
						db.useAccountNames = value 
					  end,
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP_TOOLTIP),
			default = def.onlyshowingroup,
			getFunc = function() return db.onlyshowingroup end,
			setFunc = function(value) 
						db.onlyshowingroup = value
						Toggle(true)
						onGroupChange()				
					  end,
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH_TOOLTIP),
			min = 100,
			max = 500,
			step = 10,
			default = def.window.width,
			getFunc = function() return zo_round(db.window.width) end,
			setFunc = function(value) 
						db.window.width = zo_round(value / dx) * dx
						ShowItems(addonpanel)
					  end,
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_HEIGHT),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_HEIGHT_TOOLTIP),
			min = 10,
			max = 40,
			step = 1,
			default = def.window.height,
			getFunc = function() return zo_round(db.window.height) end,
			setFunc = function(value) 
						db.window.height = zo_round(value / dx) * dx 
						ShowItems(addonpanel)
					  end,
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_MAX_DPS_UNITS),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_MAX_DPS_UNITS_TOOLTIP),
			min = 0,
			max = 12,
			step = 1,
			default = def.maxItemsDPS,
			getFunc = function() return zo_round(db.maxItemsDPS) end,
			setFunc = function(value) 
						db.maxItemsDPS = value
						ShowItems(addonpanel)
					  end,
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_MAX_HEAL_UNITS),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_MAX_HEAL_UNITS_TOOLTIP),
			min = 0,
			max = 12,
			step = 1,
			default = def.maxItemsHeal,
			getFunc = function() return zo_round(db.maxItemsHeal) end,
			setFunc = function(value) 
						db.maxItemsHeal = value
						ShowItems(addonpanel)
					  end,
		},
		{
			type = "colorpicker",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_DPS), -- or string id or function returning a string
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_DPS_TOOLTIP), -- or string id or function returning a string (optional)
			default = def.color,
			getFunc = function() return db.color.r, db.color.g, db.color.b end, --(alpha is optional)
			setFunc = function(r,g,b,a) db.color.r = r db.color.g = g db.color.b = b ShowItems(addonpanel) end, --(alpha is optional)
		},
		{
			type = "colorpicker",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_HPS), -- or string id or function returning a string
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_HPS_TOOLTIP), -- or string id or function returning a string (optional)
			default = def.color,
			getFunc = function() return db.color3.r, db.color3.g, db.color3.b end, --(alpha is optional)
			setFunc = function(r,g,b,a) db.color3.r = r db.color3.g = g db.color3.b = b ShowItems(addonpanel) end, --(alpha is optional)
		},
		{
			type = "colorpicker",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_TIME), -- or string id or function returning a string
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR_TIME_TOOLTIP), -- or string id or function returning a string (optional)
			default = def.color2,
			getFunc = function() return db.color2.r, db.color2.g, db.color2.b end, --(alpha is optional)
			setFunc = function(r,g,b,a) db.color2.r = r db.color2.g = g db.color2.b = b ShowItems(addonpanel) end, --(alpha is optional)
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_BGALPHA),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_BGALPHA_TOOLTIP),
			min = 0,
			max = 100,
			step = 1,
			default = def.bgalpha,
			getFunc = function() return db.bgalpha end,
			setFunc = function(value) 
						db.bgalpha = value
						tlw:GetNamedChild("Bg"):SetAlpha(value / 100)
					  end,
		},
		{
			type = "header",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_APPEARANCE),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_HEALER),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_HEALER_TOOLTIP),
			default = def.isHealer,
			getFunc = function() return db.isHealer end,
			setFunc = function(value) 
						db.isHealer = value 
						GDS_Switch(value)
					  end,
			reference = "GDS_SetRoleOptionControl"
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_MAXFIGHTS),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_MAXFIGHTS_TOOLTIP),
			min = 0,
			max = 50,
			step = 1,
			default = def.maxsavedfights,
			getFunc = function() return zo_round(db.maxsavedfights) end,
			setFunc = function(value) 
						db.maxsavedfights = value
					  end,
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP_TOOLTIP),
			default = def.onlyshowingroup,
			getFunc = function() return db.onlyshowingroup end,
			setFunc = function(value) 
						db.onlyshowingroup = value
						Toggle(true)
						onGroupChange()				
					  end,
		},
		{
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_UPDATETIME),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_UPDATETIME_TOOLTIP),
			min = 100,
			max = 2000,
			step = 50,
			default = def.updatetime,
			getFunc = function() return db.updatetime end,
			setFunc = function(value) 
						db.updatetime = value
					  end,
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_DEBUG),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_DEBUG_TOOLTIP),
			default = def.debug,
			getFunc = function() return db.debug end,
			setFunc = function(value) 
						db.debug = value  
						SetDebug()				
					  end,
		},
	}

	menu:RegisterOptionControls("GROUPDAMAGESHARE_OPTIONS", options)
	
	function ClearItems()
	
		if currentdata.inCombat then return end
		pool:ReleaseAllObjects()
		newanchor = GetGrowthAnchor()
		onGroupChange()
		
	end
	
	function ShowItems(currentpanel)
	
		if currentpanel ~= true and currentpanel ~= addonpanel then return end
		
		ClearItems()
		GROUPDAMAGESHARE_WRAPPER:SetHidden(false)
		Toggle("true")
		
		tlw:SetDimensions(db.window.width * 1.4, 2 * db.window.height)
		
		local maxbars = db.maxItemsDPS
		local maxbars2 = db.maxItemsHeal
		
		if maxbars > 0 then 
		
			for i = 1, maxbars do
			
				NewItem("", {name = "Player"..i, isSelf = i == 1, class = i, value = maxbars - i + 1, dpstime = maxbars - i + 1}, maxbars, maxbars, false)
				
			end
			
		end
		
		if maxbars > 0 and maxbars2 > 0 then AddSeparator() else sep:SetHidden(true) end
		
		for i = 1, maxbars2 do
		
			NewItem("", {name = "Player"..i, isSelf = i == 1, class = i, value = maxbars2 - i + 1, dpstime = maxbars2 - i + 1}, maxbars2, maxbars2, true)
			
		end
	end
	
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", ShowItems )
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", ClearItems )
	
	return menu, panel
end

-- Initialization
function Initialize(event, addon)

	if addon ~= GDS.name then return end --Only run if this addon has been loaded
 
	-- load saved variables
 
	db = ZO_SavedVars:NewAccountWide(GDS.name.."_Save", 7, nil, defaults) -- taken from Aynatirs guide at http://www.esoui.com/forums/showthread.php?t=6442
	
	if db.accountwide == false then
		db = ZO_SavedVars:NewCharacterIdSettings(GDS.name.."_Save", 7, nil, defaults)
	end
	
	-- GDS.db = db

	em:UnregisterForEvent(GDS.name.."load", EVENT_ADD_ON_LOADED)
	
	--register Events 	 	
	
	em:RegisterForEvent(GDS.name.."combat", EVENT_PLAYER_COMBAT_STATE, onCombatState)
	em:RegisterForEvent(GDS.name.."group", EVENT_UNIT_CREATED, onGroupChange)
	em:RegisterForEvent(GDS.name.."group", EVENT_UNIT_DESTROYED, onGroupChange)
	
	currentdata.inCombat = IsUnitInCombat("player")
	
	currentdata.currentfight = {units = {}}
	currentdata.lastfights = {}
	currentdata.page = 0
	currentdata.lastUpdate = 0
		
	MakeMenu()
		
	tlw = GROUPDAMAGESHARE_TLW	
	sep = tlw:GetNamedChild("Separator")
	local wrapper = tlw:GetParent()
	
	local window = db.window
		
	if window then
	
		tlw:ClearAnchors()
		tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, window.x, window.y)
		
	end
	
	local function onTLWMoveStop(control)
	
		local x, y = control:GetScreenRect()
		
		x = zo_round(x / dx) * dx
		y = zo_round(y / dx) * dx
		
		window.x = x
		window.y = y
		
		tlw:ClearAnchors()
		tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, window.x, window.y)
		
	end
	
	tlw:SetHandler("OnMoveStop", onTLWMoveStop)
	
	tlw:SetMovable(not db.locked)
	tlw:GetNamedChild("Bg"):SetAlpha(db.bgalpha / 100)
	
	newanchor = {TOPLEFT, tlw:GetNamedChild("TitleSep"), BOTTOMLEFT, 0, 4}
	
	local LGS = LibStub("LibGroupSocket")
	local dataHandler = LGS:GetHandler(LGS.MESSAGE_TYPE_COMBATSTATS)
	
	GDS.handler = dataHandler
	
	function SetRole(isHealer)		
		
		db.isHealer = isHealer
		dataHandler:SetRole(isHealer)
		
	end
	
	GDS_Switch(db.isHealer)	

	dataHandler:RegisterForValueChanges(OnUpdate)
	
	function SetDebug()
	
		dataHandler:SetDebug(db.debug)
		
	end
	 
	local fragment = ZO_SimpleSceneFragment:New(wrapper)
	
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
	
	SetDebug()
	
	ShowItems(true)
	zo_callLater(ClearItems,100)
		
	onGroupChange()
	
	SLASH_COMMANDS["/gds"] = GDS_Slash
end

-- Finally, we'll register our event handler function to be called when the proper event occurs.
em:RegisterForEvent(GDS.name.."load", EVENT_ADD_ON_LOADED, Initialize)