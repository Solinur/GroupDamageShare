local strings = {

-- Menu --

SI_GROUPDAMAGESHARE_LANG =  "en", --  "en"
SI_GROUPDAMAGESHARE_MENU_AW_NAME =  "Use Accountwide Settings", --  "Use Accountwide Settings" 
SI_GROUPDAMAGESHARE_MENU_AW_NAME_TOOLTIP =  "If chosen all cahracters on this account will have the same Settings", --  "If chosen all cahracters on this account will have the same Settings" 
SI_GROUPDAMAGESHARE_MENU_LOCK =  "Lock Frame", --  "Lock Frame" 
SI_GROUPDAMAGESHARE_MENU_LOCK_TOOLTIP =  "Locks the frame, so it can not be moved anymore", --  "Locks the frame, so it can not be moved anymore" 
SI_GROUPDAMAGESHARE_MENU_UPDATETIME =  "Update Time", --  "Update Time" 
SI_GROUPDAMAGESHARE_MENU_UPDATETIME_TOOLTIP =  "Sets the time in ms, how often the DPS/HPS bars will be updated during combat", --  "Sets the time in ms, how often the DPS/HPS bars will be updated during combat" 
SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH =  "Width", --  "Width" 
SI_GROUPDAMAGESHARE_MENU_WINDOW_WIDTH_TOOLTIP =  "Sets the width of the bars", --  "Sets the width of the bars" 
SI_GROUPDAMAGESHARE_MENU_WINDOW_HEIGHT =  "Height", --  "Height" 
SI_GROUPDAMAGESHARE_MENU_WINDOW_HEIGHT_TOOLTIP =  "Sets the height of the bars", --  "Sets the height of the bars" 
SI_GROUPDAMAGESHARE_MENU_GROWTH_DIRECTION =  "Add Frames Upwards", --  "Add Frames Upwards" 
SI_GROUPDAMAGESHARE_MENU_GROWTH_DIRECTION_TOOLTIP =  "When selected, new frames are added above the previous ones", --  "When selected, new frames are added above the previous ones" 
SI_GROUPDAMAGESHARE_MENU_BAR_DIRECTION =  "Switch Bar Direction", --  "Switch Bar Direction" 
SI_GROUPDAMAGESHARE_MENU_BAR_DIRECTION_TOOLTIP =  "When selected, the timer bar is aligned to the right", --  "When selected, the timer bar is aligned to the right" 
SI_GROUPDAMAGESHARE_MENU_DPSSOURCE =  "Data Source", --  "Data Source" 
SI_GROUPDAMAGESHARE_MENU_DPSSOURCE_TOOLTIP =  "Select which source to use for DPS/HPS", --  "Select which source to use for DPS/HPS" 
SI_GROUPDAMAGESHARE_MENU_HEALER =  "Send HPS instead of DPS", --  "Send HPS instead of DPS" 
SI_GROUPDAMAGESHARE_MENU_HEALER_TOOLTIP =  "Select if you want to transmit your HPS", --  "Select if you want to transmit your HPS" 
SI_GROUPDAMAGESHARE_MENU_MAXFIGHTS =  "Saved Fights", --  "Saved Fights" 
SI_GROUPDAMAGESHARE_MENU_MAXFIGHTS_TOOLTIP =  "Select the maximum number of fights that are saved", --  "Select the maximum number of fights that are saved" 
SI_GROUPDAMAGESHARE_MENU_MAXBARS =  "Max Units", --  "Max Units" 
SI_GROUPDAMAGESHARE_MENU_MAXBARS_TOOLTIP =  "Select the maximum number of players that are shown", --  "Select the maximum number of players that are shown" 
SI_GROUPDAMAGESHARE_MENU_DEBUG =  "Debug", --  "Debug" 
SI_GROUPDAMAGESHARE_MENU_DEBUG_TOOLTIP =  "Turns on Debug Messages", --  "Turns on Debug Messages" 
SI_GROUPDAMAGESHARE_MENU_COLOR1 =  "Main Bar Color", --  "Main Bar Color" 
SI_GROUPDAMAGESHARE_MENU_COLOR1_TOOLTIP =  "Sets the Color for the DPS/HPS bar", --  "Sets the Color for the DPS/HPS bar" 
SI_GROUPDAMAGESHARE_MENU_COLOR2 =  "Time Bar Color", --  "Time Bar Color" 
SI_GROUPDAMAGESHARE_MENU_COLOR2_TOOLTIP =  "Sets the Color for the Time bar", --  "Sets the Color for the Time bar" 
SI_GROUPDAMAGESHARE_MENU_BGALPHA =  "Background Transparency", --  "Background Transparency" 
SI_GROUPDAMAGESHARE_MENU_BGALPHA_TOOLTIP =  "Sets the Transparency of the Background", --  "Sets the Transparency of the Background" 
SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP =  "Only show in group", --  "Only show in group" 
SI_GROUPDAMAGESHARE_MENU_SHOWINGROUP_TOOLTIP =  "Hides the window when not in group", --  "Hides the window when not in group" 

}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end