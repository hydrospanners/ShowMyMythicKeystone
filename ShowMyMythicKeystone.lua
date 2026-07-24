local AddonName = ...

local frame, text
local keystoneLink
local iconAnchor

-- Lindormi is the English name. Other clients show a localised one, so only
-- name her on enUS instead of sending people looking for a stranger.
local NO_KEY_HINT = GetLocale() == "enUS"
    and "|cff909090Talk to Lindormi for a key|r"
    or "|cff909090Get a new key from the keystone NPC|r"

-- The keystone the player owns, or nil. Returns the map ID rather than the
-- name: the name is nil until the challenge-mode map table has arrived, and
-- treating that as "no key" would show the wrong hint.
local function GetKeystone()
    if not (C_MythicPlus and C_MythicPlus.GetOwnedKeystoneChallengeMapID) then return end

    local challengeMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if type(challengeMapID) ~= "number" or challengeMapID == 0 then return end

    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if type(level) ~= "number" or level == 0 then return end

    return challengeMapID, level
end

-- The actual item link, so shift-click can share it like any other item.
local function FindKeystoneLink()
    for bagID = 0, NUM_BAG_SLOTS do
        for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
            local itemID = C_Container.GetContainerItemID(bagID, slotID)
            if itemID and C_Item.IsItemKeystoneByID(itemID) then
                return C_Container.GetContainerItemLink(bagID, slotID)
            end
        end
    end
end

-- Has this character run any M+ this season? Without it, neither hint applies.
local function HasMythicPlusProgress()
    if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then return false end
    local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
    return type(summary) == "table" and (summary.currentSeasonScore or 0) > 0
end

-- An unclaimed vault reward earned from Mythic+ hands out a keystone with it.
local function VaultHasKeystone()
    if not (C_WeeklyRewards and C_WeeklyRewards.HasAvailableRewards) then return false end
    if not C_WeeklyRewards.HasAvailableRewards() then return false end

    local activities = C_WeeklyRewards.GetActivities()
    if type(activities) ~= "table" then return false end

    for _, activity in ipairs(activities) do
        if activity.type == Enum.WeeklyRewardChestThresholdType.Activities
            and (activity.threshold or 0) > 0
            and (activity.progress or 0) >= activity.threshold then
            return true
        end
    end
    return false
end

-- Sit in the gap above the dungeon icon row, which is where the rating is.
-- Horizontal placement comes from the panel itself: the rating block's own
-- frame is not where its text draws, so anchoring to it lands off-screen.
local function PositionFrame()
    -- Blizzard builds the icon frames lazily in ChallengesFrame_Update, well
    -- after ADDON_LOADED, so keep looking until they exist.
    if not iconAnchor then
        local icons = ChallengesFrame.DungeonIcons
        iconAnchor = icons and icons[1]
    end

    local panelTop = ChallengesFrame:GetTop()
    local iconTop = iconAnchor and iconAnchor:GetTop()

    frame:ClearAllPoints()
    if panelTop and iconTop then
        frame:SetPoint("TOP", ChallengesFrame, "TOP", 0, iconTop - panelTop + 36)
    else
        frame:SetPoint("TOP", ChallengesFrame, "TOP", 0, -320)
    end
end

local function Refresh()
    if not frame then return end

    local challengeMapID, keyLevel = GetKeystone()
    local msg
    keystoneLink = nil

    if challengeMapID then
        keystoneLink = FindKeystoneLink()
        local name = C_ChallengeMode.GetMapUIInfo(challengeMapID)
        msg = ("|cffa335ee[%s +%d]|r"):format(name or "Keystone", keyLevel)
    elseif not HasMythicPlusProgress() then
        -- Fresh character, no season score: nothing here is useful yet.
        msg = nil
    elseif VaultHasKeystone() then
        msg = "|cffffd100Claim your vault to get a key|r"
    else
        msg = NO_KEY_HINT
    end

    if ShowMyMythicKeystoneDB.hidden or not msg then
        frame:Hide()
        return
    end

    text:SetText(msg)
    frame:SetWidth(text:GetStringWidth() + 16)
    frame:SetHeight(text:GetStringHeight() + 4)
    -- Only take clicks when there is something to link, so the frame never
    -- swallows input meant for Blizzard's panel underneath.
    frame:EnableMouse(keystoneLink ~= nil)
    PositionFrame()
    frame:Show()
end

-- The Mythic+ Dungeons tab lives in Blizzard_ChallengesUI, which is
-- load-on-demand, so this runs from that addon's ADDON_LOADED.
local function AttachToChallengesFrame()
    if frame then return end

    if not ChallengesFrame then
        C_Timer.After(1, AttachToChallengesFrame)
        return
    end

    frame = CreateFrame("Frame", "ShowMyMythicKeystoneFrame", ChallengesFrame)
    -- The panel's own art sits on inner frames with higher levels than
    -- ChallengesFrame, so clear the lot of them.
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(ChallengesFrame:GetFrameLevel() + 50)

    -- The keystone's own tooltip, exactly as if you hovered it in your bags.
    frame:SetScript("OnEnter", function(self)
        if not keystoneLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(keystoneLink)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)

    -- Shift-click into an open chat box, same as clicking the key in your bags.
    frame:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not keystoneLink then return end
        if HandleModifiedItemClick(keystoneLink) then return end
        if IsShiftKeyDown() then
            ChatEdit_InsertLink(keystoneLink)
        end
    end)

    text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")

    ChallengesFrame:HookScript("OnShow", Refresh)
    Refresh()
end

local function Print(msg)
    print("|cffa335eeShowMyMythicKeystone|r: " .. msg)
end

SLASH_SHOWMYMYTHICKEYSTONE1 = "/showmymythickeystone"
SLASH_SHOWMYMYTHICKEYSTONE2 = "/smk"
SlashCmdList.SHOWMYMYTHICKEYSTONE = function(msg)
    local cmd = msg:lower():match("^(%S*)")

    if cmd == "show" then
        ShowMyMythicKeystoneDB.hidden = false
    elseif cmd == "hide" then
        ShowMyMythicKeystoneDB.hidden = true
    elseif cmd == "" or cmd == "toggle" then
        ShowMyMythicKeystoneDB.hidden = not ShowMyMythicKeystoneDB.hidden
    else
        Print("/smk show, /smk hide, or /smk on its own to toggle.")
        return
    end

    Refresh()
    Print(ShowMyMythicKeystoneDB.hidden and "keystone line hidden." or "keystone line shown.")
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" then
        if addonName == AddonName then
            ShowMyMythicKeystoneDB = ShowMyMythicKeystoneDB or { hidden = false }
        elseif addonName == "Blizzard_ChallengesUI" then
            AttachToChallengesFrame()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Populates the challenge-mode map names GetMapUIInfo reads from.
        C_MythicPlus.RequestMapInfo()

        -- Already loaded if something else pulled the panel in before us.
        if C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") then
            AttachToChallengesFrame()
            self:UnregisterEvent("ADDON_LOADED")
        end

        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("BAG_UPDATE_DELAYED")
        watcher:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
        watcher:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        watcher:RegisterEvent("WEEKLY_REWARDS_UPDATE")
        watcher:SetScript("OnEvent", Refresh)

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
