# GroupDamageShare
Allow to share your DPS/HPS with players in the group that also run this addon.

## Description

This addon requires the following libraries:

* [LibAddonMenu](https://www.esoui.com/downloads/info7-LibAddonMenu.html)
* [LibStub](https://www.esoui.com/downloads/info44-LibStub.html)
* [LibGroupSocket](https://www.esoui.com/downloads/info1337-LibGroupSocket.html)
* [LibGPS2](https://www.esoui.com/downloads/info601-LibGPS2.html)
* [LibMapPing](https://www.esoui.com/downloads/info1302-LibMapPing.html)
* LibCombat (internal)

They are included in the release and have to be enabled in the AddOns panel ingame.

** Please note that currently only one addon with sharing of Information (DPS, Ultimae, Resources ... ) can be active.**

**Group Damage Share** is an attempt to provide a feature that was unique to [FTC](http://www.esoui.com/downloads/info28-FoundryTacticalCombatFTC.html).  

It uses pings on the map to comunicate with the addon from another player to transmit your current DPS or HPS values. (for more details on this refer to the description of [LibGroupSocket](http://www.esoui.com/downloads/info1337-LibGroupSocket.html)). With **Group Damage Share** you can watch during the fight how the DPS/HPS of your groupmembers develops. 

Please note that this addon cannot show the DPS of group members who don't use this addon [B][COLOR="Yellow"]and[/COLOR][/B] enable sharing. 
Setup + Installation:

* Download and install the addon
* Create a group
* Go to the group window and click on "LibGroupSocket sending" so that it says "On"
* For now settings are spread to two places (in the usual addon settings area): "Group Damage Share" and "LibGroupSocket"
* If you want to turn sending on permanently you need to install [URL="http://www.esoui.com/downloads/info1337-LibGroupSocket.html"]LibGroupSocket[/URL] as a standalone version. Refer to the description for more details.


Current features

* Share your DPS or HPS as well as the combat time with your group
* View DPS/HPS and combat time shared by your group (you don't have to enable sharing on to see the values shared by others)
* The Icon on the left shows the class and its color the main resource (Magicka/Stamina) of the players

============================================

Planned Features:

* Show both DPS/HPS in the window at the same time
* Transmit DPS/HPS alternating so both data is available
* Implement a standalone DPS meter so it doesn't rely on other DPS addons anymore


Big thanks to [sirinsidiator](http://www.esoui.com/forums/member.php?action=getinfo&userid=5815) for creating the library for the data transfer: [LibGroupSocket](http://www.esoui.com/downloads/info1337-LibGroupSocket.html). 

*Decay2 aka Solinur (Pact EU)*
