local em = GetEventManager()
local _
local db,newanchor,active,tlw
local dx = 1/GetSetting(SETTING_TYPE_UI, UI_SETTING_CUSTOM_SCALE) --Get UI Scale to draw thin lines correctly
UI_SCALE = dx
local activelyhidden = false

-- Addon Namespace
GDS = GDS or {}
GDS.name 		= "GroupDamageShare"
GDS.version 	= "0.2.8"

local function Print(message, ...)
	if db.debug then df("[%s] %s", GDS.name, message:format(...)) end
end

GDS.Print = Print

function GDS.spairs(t, order) -- from https://stackoverflow.com/questions/15706270/sort-a-table-in-lua
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

local pool = ZO_ObjectPool:New(function(objectPool)
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
	
	
function GDS.NewItem(unitName,unitData,maxvalue,maxtime,isself,class)  -- Adds an item to the taunt list,
	if pool:GetActiveObjectCount() >= db.maxitems then return end
	local alpha = isself and 1 or 0.7
	local item,key = pool:AcquireObject()
	item.key = key
	local barsize1 = (unitData.value or 1)/(maxvalue or 1)*db.window.width
	local barsize2 = (unitData.dpstime or 1)/(maxtime or 1)*db.window.width*0.4
	local iconcolor
	if class>16 then
		iconcolor = {1,1,1,1}
		class=class-16
	elseif class>8 then
		iconcolor = {0.6,0.6,1,1}
		class=class-8
	else 
		iconcolor = {0.6,1,0.6,1}
	end
	local icontex = classIconTex[class]
	item:SetHidden(false)
	item:SetAnchor(unpack(newanchor))
	item:GetNamedChild("Label"):SetText(zo_strformat("<<!aC:1>>",unitName))
	item:GetNamedChild("Label"):SetFont("EsoUi/Common/Fonts/Univers57.otf".."|"..db.window.height-(3*dx)..'|soft-shadow-thin')
	item:GetNamedChild("Icon"):SetDimensions(db.window.height,db.window.height)
	item:GetNamedChild("Icon"):SetTexture(icontex)
	item:GetNamedChild("Icon"):SetColor(unpack(iconcolor))
	item:GetNamedChild("Bg"):SetEdgeTexture("",1,1,1)
	item:GetNamedChild("Bg"):SetDimensions(db.window.width,db.window.height)
	item:GetNamedChild("Bg2"):SetEdgeTexture("",1,1,1)
	item:GetNamedChild("Bg2"):SetDimensions(db.window.width*0.4,db.window.height)
	item:GetNamedChild("Bar"):SetDimensions(barsize1,db.window.height)
	item:GetNamedChild("Bar"):SetColor(db.color.r,db.color.g,db.color.b,alpha)
	item:GetNamedChild("Bar2"):SetDimensions(barsize2,db.window.height)
	item:GetNamedChild("Bar2"):SetColor(db.color2.r,db.color2.g,db.color2.b,alpha)
	item:GetNamedChild("Value"):SetHeight(db.window.height)
	item:GetNamedChild("Value"):SetFont("EsoUi/Common/Fonts/Univers57.otf".."|"..db.window.height-(3*dx)..'|soft-shadow-thin')
	item:GetNamedChild("Value"):SetText(unitData.value or 1000)	
	item:GetNamedChild("Time"):SetHeight(db.window.height)
	item:GetNamedChild("Time"):SetFont("EsoUi/Common/Fonts/Univers57.otf".."|"..db.window.height-(3*dx)..'|soft-shadow-thin')
	item:GetNamedChild("Time"):SetText((unitData.dpstime or 10).." s")
	
	newanchor = GDS.GetGrowthAnchor(item)  -- new anchor for the next item 

	return key
end

function GDS.Toggle(show)
	if show==nil then show=tlw:IsHidden() end
	tlw:SetHidden(not show)
end

function GDS.Slash(extra)
	local show  = tlw:IsHidden()
	activelyhidden = (not show)
	GDS.Toggle(show)
end

function GDS.onGroupChange()
	if db.onlyshowingroup and (not activelyhidden) then GDS.Toggle(IsUnitGrouped("player")) end
	if IsUnitGrouped("player")==false then activelyhidden=false end
end

function GDS_Hide()
	activelyhidden = true
	GDS.Toggle(false)
end

function GDS_Selector(button)
	local page = GDS.currentpage
	if button == 1 or button == -1 then 
		page = page + button
	elseif button == "end" then 
		page = 1
	end
	page = math.max(math.min(math.min(db.maxsavedfights, #GDS.SavedData), page), 1)
	GDS.currentpage = page
	GDS.OnUIUpdate()
	Print("Current Page: %s", page)
end

function GDS_Switch()
	GDS.ShowHeals = not GDS.ShowHeals
	local texture = GDS.ShowHeals and "esoui/art/lfg/lfg_healer_down_64.dds" or "esoui/art/lfg/lfg_dps_down_64.dds"
	tlw:GetNamedChild("IconSwitch"):SetTexture(texture)
	GDS.OnUIUpdate()
end

function GDS.GetGrowthAnchor(item)
	local a1 = db.growthdirection and BOTTOMLEFT or TOPLEFT 
	local a2 = db.growthdirection and TOPLEFT or BOTTOMLEFT 	
	local sp = db.growthdirection and -2 or 2
	local anchor = {a1, item, a2, 0, sp}
	if item==nil then anchor = {a1, tlw:GetNamedChild("Sep"), a2, 0, 4} end
	return anchor
end 


-- EVENT_EFFECT_CHANGED ( eventCode,  changeType,  effectSlot,  effectName,  unitTag,  beginTime,  endTime,  stackCount,  iconName,  buffType,  effectType,  abilityType,  statusEffectType,  unitName,  unitId,  abilityId) 

function GDS.OnUpdate(unitName, value, isheal, dpstime, isSelf, class)
	-- if isSelf then unitName = "player" end
	if GDS.data.units[unitName]==nil then GDS.data.units[unitName]={} end
	GDS.data.units[unitName]["isheal"]=isheal
	GDS.data.units[unitName].value=value
	GDS.data.units[unitName].isSelf=isSelf
	GDS.data.units[unitName].class=class
	if dpstime and dpstime > 0 then GDS.data.units[unitName].dpstime = dpstime end
	GDS.currentpage = 0
	if(not active and IsUnitGrouped("player")) then
		EVENT_MANAGER:RegisterForUpdate(GDS.name.."LiveUpdate", db.updatetime, GDS.OnUIUpdate)
		active = true
	end
	GDS.lastUpdate=GetTimeStamp()
end

function GDS.OnUIUpdate()
	local data = (GDS.currentpage == 0 and GDS.data) or GDS.SavedData[GDS.currentpage]
	pool:ReleaseAllObjects()
	newanchor = GDS.GetGrowthAnchor()
	if data==nil or data.units==nil then return end
	local maxvalue = 1
	local maxtime = 1
	for k,v in pairs(data.units) do 
		if v["isheal"] == GDS.ShowHeals then
			maxvalue = math.max(v["value"],maxvalue)
			maxtime = math.max(v["dpstime"] or 0,maxtime)
		end		
	end	
	for k,v in GDS.spairs(data.units, function(t,a,b) return t[a]["value"]>t[b]["value"] end) do 
		if v["isheal"] == GDS.ShowHeals then
			GDS.NewItem(k,v,maxvalue,maxtime,v.isSelf,v.class)
		end		
	end
	tlw:GetNamedChild("Label"):SetText(data.time)
	if (GetTimeStamp()-GDS.lastUpdate)>3 then 
		if active then
			Print("Stop Update")
			EVENT_MANAGER:UnregisterForUpdate(GDS.name.."LiveUpdate")
			active = false
		end
	end
end

function GDS.onCombatState()
	local inCombat = IsUnitInCombat("player")
	GDS.inCombat = inCombat
	if inCombat == false then 
		zo_callLater(GDS.onCombatEnd,2500) 
	elseif inCombat == true then
		GDS.onCombatStart()
	end 
end

function GDS.SaveData(data)
	local savedData = GDS.SavedData
	table.insert(savedData,1,data)
	if #savedData > db.maxsavedfights then table.remove(savedData) end
end

function GDS.onCombatStart()
	if IsUnitDead("player") then return end
	Print("Combat Start")
	GDS.currentpage = 0
	GDS.data = {units={}}
	GDS.data.time = GetDateStringFromTimestamp(GetTimeStamp())..", "..GetTimeString()
	pool:ReleaseAllObjects()
	newanchor = GDS.GetGrowthAnchor()
end

function GDS.onCombatEnd()
	if GDS.inCombat or IsUnitDead("player") or SCENE_MANAGER:IsShowingNext("GROUPDAMAGESHARE_MOVE_SCENE") then return end
	Print("Combat End")
	GDS.SaveData(GDS.data)
	GDS.currentpage = 1
end

function GDS.MakeMenu()
    -- load the settings->addons menu library
	local menu = LibStub("LibAddonMenu-2.0")
	local def = GDS.defaults 

    -- the panel for the addons menu
	local panel = {
		type = "panel",
		name = "Group Damage Share",
		displayName = "GroupDamageShare",
		author = "Solinur",
        version = GDS.version or "",
		registerForRefresh = false,
	}
	
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
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH_TOOLTIP),
			min = 100,
			max = 500,
			step = 10,
			default = def.window.width,
			getFunc = function() return zo_round(db.window.width) end,
			setFunc = function(value) 
						db.window.width = zo_round(value/dx)*dx
						GDS.ShowItems(addonpanel)
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
						db.window.height = zo_round(value/dx)*dx 
						GDS.ShowItems(addonpanel)
					  end,
		},
		{
			type = "checkbox",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_HEALER),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_HEALER_TOOLTIP),
			default = def.ishealer,
			getFunc = function() return db.ishealer end,
			setFunc = function(value) 
						db.ishealer = value  				
					  end,
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
			type = "slider",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_MAXBARS),
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_MAXBARS_TOOLTIP),
			min = 3,
			max = 12,
			step = 1,
			default = def.maxitems,
			getFunc = function() return zo_round(db.maxitems) end,
			setFunc = function(value) 
						db.maxitems = value
						GDS.ShowItems(addonpanel)
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
						GDS.SetDebug()				
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
						GDS.Toggle(true)
						GDS.onGroupChange()				
					  end,
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
						tlw:GetNamedChild("Bg"):SetAlpha(value/100)
					  end,
		},
		{
			type = "colorpicker",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR1), -- or string id or function returning a string
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR1_TOOLTIP), -- or string id or function returning a string (optional)
			default = def.color,
			getFunc = function() return db.color.r, db.color.g, db.color.b end, --(alpha is optional)
			setFunc = function(r,g,b,a) db.color.r=r db.color.g=g db.color.b=b GDS.ShowItems(addonpanel) end, --(alpha is optional)
		},
		{
			type = "colorpicker",
			name = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR2), -- or string id or function returning a string
			tooltip = GetString(SI_GROUPDAMAGESHARE_MENU_COLOR2_TOOLTIP), -- or string id or function returning a string (optional)
			default = def.color2,
			getFunc = function() return db.color2.r, db.color2.g, db.color2.b end, --(alpha is optional)
			setFunc = function(r,g,b,a) db.color2.r=r db.color2.g=g db.color2.b=b GDS.ShowItems(addonpanel) end, --(alpha is optional)
		}
	}

	menu:RegisterOptionControls("GROUPDAMAGESHARE_OPTIONS", options)
	
	function GDS.ClearItems()
		if GDS.inCombat then return end
		pool:ReleaseAllObjects()
		newanchor = GDS.GetGrowthAnchor()
		GDS.onGroupChange()
	end
	
	function GDS.ShowItems(currentpanel)
		if currentpanel~=true and currentpanel~=addonpanel then return end
		GDS.ClearItems()
		GROUPDAMAGESHARE_WRAPPER:SetHidden(false)
		GDS.Toggle("true")
		tlw:SetDimensions(db.window.width*1.4,2*db.window.height)
		for i=1,12 do
			GDS.NewItem("Player"..i,{},nil,nil,i==1,math.fmod(i-1,8)+1)
		end
	end
	
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", GDS.ShowItems )
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", GDS.ClearItems )
	
	return menu
end

-- default values (see http://wiki.esoui.com/AddOn_Quick_Questions#How_do_I_save_settings_on_the_local_machine.3F)
GDS.defaults = {
	["window"]={x=150*dx,y=150*dx,height=zo_round(20/dx)*dx,width=zo_round(240/dx)*dx},
	["locked"]=false,
	["ishealer"]=false,
	["updatetime"]=250,
	["maxsavedfights"]=15,
	["maxitems"]=6,
	["debug"]=false,
	["color"]={r=0,b=0,g=0.8},
	["color2"]={r=0.8,b=0,g=0.8},
	["bgalpha"]=1,
	["accountwide"]=false,
	["onlyshowingroup"]=true,	
}

-- Initialization
function GDS:Initialize(event, addon)

	if addon ~= self.name then return end --Only run if this addon has been loaded
 
	-- load saved variables
 
	db = ZO_SavedVars:NewAccountWide(self.name.."_Save", 7, nil, self.defaults) -- taken from Aynatirs guide at http://www.esoui.com/forums/showthread.php?t=6442
	
	if db.accountwide == false then
		db = ZO_SavedVars:NewCharacterIdSettings(self.name.."_Save", 7, nil, self.defaults)
	end

	em:UnregisterForEvent(self.name.."load", EVENT_ADD_ON_LOADED)
	
	--register Events 	 	
	
	em:RegisterForEvent(self.name.."combat", EVENT_PLAYER_COMBAT_STATE, self.onCombatState)
	em:RegisterForEvent(self.name.."alive", EVENT_PLAYER_ALIVE, self.onCombatState)
	em:RegisterForEvent(self.name.."alive", EVENT_UNIT_CREATED, self.onGroupChange)
	em:RegisterForEvent(self.name.."alive", EVENT_UNIT_DESTROYED, self.onGroupChange)
	
	self.playername = zo_strformat("<<!aC:1>>",GetUnitName("player"))
	self.inCombat = IsUnitInCombat("player")
	self.ShowHeals = not db.ishealer
	self.data = {units={}}
	self.SavedData = {}
	self.currentpage = 0
	self.lastUpdate = 0
		
	self.MakeMenu()
		
	tlw = GROUPDAMAGESHARE_TLW
		
	if (db.window) then
		tlw:ClearAnchors()
		tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, db.window.x, db.window.y)
	end
	
	tlw:SetHandler("OnMoveStop", function(control)
		local x, y = control:GetScreenRect()
		x = zo_round(x/dx)*dx
		y = zo_round(y/dx)*dx
		db.window.x=x
		db.window.y=y
		tlw:ClearAnchors()
		tlw:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, db.window.x, db.window.y)
	end)
	
	tlw:SetMovable(not db.locked)
	tlw:GetNamedChild("Bg"):SetAlpha(db.bgalpha/100)
	GDS_Switch()
	
	local anchorside = growthdirection and BOTTOMLEFT or TOPLEFT
	
	newanchor = {anchorside, tlw:GetNamedChild("Sep"), anchorside, 0, 4}
	
	local LGS = LibStub("LibGroupSocket")
	local dataHandler = LGS:GetHandler(LGS.MESSAGE_TYPE_COMBATSTATS)
	dataHandler.db.ishealer = db.ishealer

	dataHandler:RegisterForValueChanges(GDS.OnUpdate)
	
	function GDS.SetDebug() 
		dataHandler:SetDebug(db.debug)
	end
	 
	local wrapper = GROUPDAMAGESHARE_WRAPPER 
	 
	local fragment = ZO_SimpleSceneFragment:New(wrapper)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
	
	GDS.SetDebug()
	
	GDS.ShowItems(true)
	zo_callLater(GDS.ClearItems,100)
		
	GDS.onGroupChange()
	
	SLASH_COMMANDS["/gds"] = GDS.Slash
end

-- Finally, we'll register our event handler function to be called when the proper event occurs.
em:RegisterForEvent(GDS.name.."load", EVENT_ADD_ON_LOADED, function(...) GDS:Initialize(...) end)