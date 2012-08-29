--[[
	Shamelessly borrowed ideas on how to go about doing this.
	Please check the readme file as there may be some important
	information.  :)
	
	Still a simple script and still released in public domain.
	Nuggs
]]--
NDEMONIC_VERSION = "0.1.8"

nDemonic_Options = {};
local nDemonic_TimeSinceLastUpdate = 0;
local nDemonic_UpdateInterval = 0.2;

local function nDemonic_Disable()
	DisableAddOn("nDemonic");
	ReloadUI();
end

StaticPopupDialogs["DISABLE_NDEMONIC"] = {
	text = "You're not currently logged into a warlock, disabling the AddOn.",
	button1 = "Accept", OnAccept = nDemonic_Disable, timeout = 0, whileDead = 1,
};

local nTeleport = GetSpellInfo(48020);
local nSummon = GetSpellInfo(48018);

local nDemonic_SpellInfo = {
	nActive			= false,	-- do we have a portal up
	nFinished		= 0,		-- time it's scheduled to expire
	nCooldown		= 0,		-- time left on cooldown
	nMessage		= nil,		-- message to display, don't change
	nDispText		= true,		-- display text message(Icon or text must be true)
	nLocked			= true		-- Is the frame locked?
};

local function nDemonic_InRange()
	local usable, nomana = IsUsableSpell(nTeleport);

	if (not usable and not nomana) then
		return false
	else
		return true
	end
end

local nDemonic = CreateFrame("Frame", "nDemonic", UIParent)
nDemonic:SetWidth(200)
nDemonic:SetHeight(22)

local nDemonicText = nDemonic:CreateFontString(nDemonic, "ARTWORK", "GameFontNormal")

local function nDemonic_CreateTexture()
	nDemonicTexture = nDemonic:CreateTexture(nil, "BACKGROUND")
	nDemonicTexture:SetTexture(nil)
	nDemonicTexture:SetAllPoints(nDemonic)
	nDemonic.texture = nDemonicTexture
	nDemonicText:SetAllPoints(nDemonic)
	nDemonicText:SetFont("Interface\\AddOns\\nDemonic\\Fonts\\times_new_yorker.ttf", 14, "OUTLINE")
end

-- Set the cooldown and adjust it if we have it glyphed.
local function nDemonic_SetCooldown(duration)
	for i = 1, GetNumGlyphSockets() do
		if (select(4, GetGlyphSocketInfo(i)) == 63309) then
			duration = duration - 4;
		end
	end
	nDemonic_SpellInfo.nCooldown = time() + duration;
end

local function nDemonic_SetMessage(MessageType)
	if (MessageType == 2) then -- On cooldown
		nDemonic_SpellInfo.nMessage = "Demonic Circle: On Cooldown!";
		nDemonicText:SetTextColor(1, 0, 0);
		nDemonicText:SetText(nDemonic_SpellInfo.nMessage);
	elseif (MessageType == 0) then -- In range
		nDemonic_SpellInfo.nMessage = "Demonic Circle: In Range!";
		nDemonicText:SetTextColor(0, 1, 0);
		nDemonicText:SetText(nDemonic_SpellInfo.nMessage);
	elseif (MessageType == 1) then -- Out of range
		nDemonic_SpellInfo.nMessage = "Demonic Circle: Out of Range!";
		nDemonicText:SetTextColor(1, 0, 0);
		nDemonicText:SetText(nDemonic_SpellInfo.nMessage);
	elseif (MessageType == 3) then -- This is for when we clear the portal
		nDemonic_SpellInfo.nMessage = "";
	end
end

local function nDemonic_Lock()
	nDemonic:SetMovable(false);
	nDemonic:EnableMouse(false);
	nDemonic_SpellInfo.nLocked = true;
	nDemonicTexture:SetTexture(nil);
	DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnDemonic: |cff00fffflocked|r");
end

local function nDemonic_Unlock()
	nDemonic:SetMovable(true); nDemonic:EnableMouse(true);
	nDemonic_SpellInfo.nLocked = false;
	nDemonicTexture:SetTexture(0, 0, 1, .5);
	DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnDemonic: |cff00ffffunlocked|r");
end

local function nDemonic_Clear()
	nDemonic_SpellInfo.nActive = false;
	nDemonic_SpellInfo.nFinished = 0;
	nDemonic_SetMessage(3);
	nDemonic:Hide();
end

local function nDemonic_Reset()
	DEFAULT_CHAT_FRAME:AddMessage("|cFF008B8BnDemonic: |cff00ffffreset|r");
end

function nDemonic:ADDON_LOADED(name)
	if (name == "nDemonic") then
		if (nDemonic_Options.x == nil) then
			nDemonic_Options.x = 0;
		end

		if (nDemonic_Options.y == nil) then
			nDemonic_Options.y = 0;
		end
		
		if (nDemonic_Options.Anchor == nil) then
			nDemonic_Options.Anchor = "CENTER";
		end
		nDemonic_CreateTexture();
		nDemonic:ClearAllPoints();
		nDemonic:SetPoint(nDemonic_Options.Anchor, nDemonic_Options.x, nDemonic_Options.y);
		nDemonic:SetToplevel(true);
	end
end

function nDemonic:PLAYER_LOGIN()
	if (select(2,UnitClass("player")) == "WARLOCK") then
		nDemonic:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
		nDemonic:RegisterEvent("PLAYER_DEAD");
		nDemonic:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	else
		StaticPopup_Show("DISABLE_NDEMONIC");
	end
	nDemonic:UnregisterEvent("PLAYER_LOGIN");
end

function nDemonic:COMBAT_LOG_EVENT_UNFILTERED(...)
	local _, eventType, _, guid, _, _, _, _, _, _, _, _, spellName = ...

	if (guid == UnitGUID("player") and eventType == "SPELL_CREATE" and spellName == nSummon) then
		nDemonic_SpellInfo.nActive = true;
		nDemonic_SpellInfo.nFinished = time() + 360; -- Six minutes
		nDemonic_SetMessage(0);
		nDemonic:Show();
	end
	if (guid == UnitGUID("player") and eventType == "SPELL_CAST_SUCCESS" and spellName == nTeleport) then
		nDemonic_SetCooldown(25);
		nDemonic_SetMessage(2);
	end
end

function nDemonic:PLAYER_DEAD()
	nDemonic_Clear();
end

function nDemonic:ZONE_CHANGED_NEW_AREA()
	nDemonic_Clear();
end

function nDemonic_OnUpdate(self, elapsed)
	nDemonic_TimeSinceLastUpdate = nDemonic_TimeSinceLastUpdate + elapsed;

	while (nDemonic_TimeSinceLastUpdate > nDemonic_UpdateInterval) do
		if (nDemonic_SpellInfo.nActive) then
			if (nDemonic_SpellInfo.nFinished == time()) then
				nDemonic_Clear();
			else
				if (nDemonic_InRange() and nDemonic_SpellInfo.nCooldown == 0) then
					if (nDemonic_SpellInfo.nDispText and nDemonic_SpellInfo.nMessage ~= "Demonic Circle: In Range!") then
						nDemonic_SetMessage(0);
					end
				elseif (nDemonic_SpellInfo.nDispText and nDemonic_SpellInfo.nMessage ~= "Demonic Circle: Out of Range!" and nDemonic_SpellInfo.nCooldown == 0) then
					nDemonic_SetMessage(1);
				end
				if (nDemonic_SpellInfo.nCooldown > time()) then
					if (nDemonic_SpellInfo.nDispText and nDemonic_SpellInfo.nMessage ~= "Demonic Circle: On Cooldown!") then
						nDemonic_SetMessage(2);
					end
				elseif (nDemonic_SpellInfo.nCooldown == time()) then
					nDemonic_SpellInfo.nCooldown = 0;
					if (nDemonic_InRange() == true) then
						nDemonic_SetMessage(0);
					else
						nDemonic_SetMessage(1);
					end
				end
			end
		end
		nDemonic_TimeSinceLastUpdate = nDemonic_TimeSinceLastUpdate - nDemonic_UpdateInterval;
	end
end

nDemonic_Help = {
	"|cff00ffffnDemonic " ..GAME_VERSION_LABEL.. ":|r |cFF008B8B" ..NDEMONIC_VERSION.."|r",
	"  |cFF008B8B/ndemonic reset|r" .. "   - |cff00ffffReset nDemonic to it's default settings.|r",
	"  |cFF008B8B/ndemonic lock|r" .. "     - |cff00ffffLock nDemonic.|r",
	"  |cFF008B8B/ndemonic unlock|r" .. " - |cff00ffffUnlock nDemonic|r",
};

SlashCmdList['NDEMONIC'] = function(arg)
	if (arg == 'lock') then
		nDemonic_Lock();
	elseif (arg == 'unlock') then
		nDemonic_Unlock();
	elseif (arg == 'reset') then
		nDemonic_Reset();
	else
		for _, msg in ipairs(nDemonic_Help) do
			DEFAULT_CHAT_FRAME:AddMessage(msg);
		end
	end
end
SLASH_NDEMONIC1 = '/ndemonic'
SLASH_NDEMONIC2 = '/nd'

nDemonic:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end);
nDemonic:SetScript("OnMouseDown", function(self, button)
	if (nDemonic_SpellInfo.nLocked == false) then
		if (button == "LeftButton" and not nDemonic.isMoving) then
			nDemonic:StartMoving();
			nDemonic.isMoving = true;
		end
	end
end)

nDemonic:SetScript("OnMouseUp", function()
	if (nDemonic.isMoving) then
		nDemonic:StopMovingOrSizing();
		nDemonic.isMoving = false;

		local point, relativeTo, relativePoint, xOfs, yOfs = nDemonic:GetPoint();
		nDemonic_Options.x = xOfs;
		nDemonic_Options.y = yOfs;
		nDemonic_Options.Anchor = relativePoint;
	end
end)
nDemonic:SetScript("OnUpdate", nDemonic_OnUpdate);
nDemonic:RegisterEvent("PLAYER_LOGIN");
nDemonic:RegisterEvent("ADDON_LOADED");