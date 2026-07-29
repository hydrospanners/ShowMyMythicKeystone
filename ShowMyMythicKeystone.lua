local AddonName = ...

local frame, text
local keystoneLink
local iconAnchor

-- The alt list: a container parented to ChallengesFrame plus a pool of font
-- string pairs, one pair per character (name line, keystone line).
local altFrame
local altRows = {}

-- How far in from the panel's right edge the alt column sits, and the gaps
-- between the two lines of one entry and between entries.
local ALT_RIGHT_INSET = 40
local ALT_LINE_GAP = 1
local ALT_ENTRY_GAP = 8

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

--------------------------------------------------------------------------------
-- Cross-character keystone store
--
-- Keys only matter for the week they were earned in, so the store is emptied at
-- every weekly reset and refills as characters are played. A character you have
-- not logged into this week has no row at all, which is the honest answer --
-- there is no way to read another character's key while it is offline.
--------------------------------------------------------------------------------

local function CharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    if not name or not realm then return end
    return name .. "-" .. realm, name, realm
end

-- Blizzard's own reset clock, so this is right in every region without the
-- addon ever knowing which region it is in.
local function WeeklyResetDeadline()
    if not (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset) then return end
    local ok, seconds = pcall(C_DateAndTime.GetSecondsUntilWeeklyReset)
    if not ok or type(seconds) ~= "number" then return end
    return time() + seconds
end

-- Wipe the store when the stored deadline has passed. Called at login and on
-- every refresh, so a reset that happens mid-session is caught on the next
-- panel open rather than lingering until relog.
local function CheckWeeklyReset()
    local db = ShowMyMythicKeystoneDB
    if not db then return end

    local deadline = WeeklyResetDeadline()
    if not deadline then return end

    if type(db.weeklyReset) == "number" and db.weeklyReset <= time() then
        db.chars = {}
    end
    db.weeklyReset = deadline
end

-- Record (or clear) this character's key. Clearing matters: once you burn the
-- key the row has to go, or the list claims you still have it.
local function RecordSelf()
    local db = ShowMyMythicKeystoneDB
    if not db then return end
    db.chars = db.chars or {}

    local key = CharacterKey()
    if not key then return end

    local challengeMapID, level = GetKeystone()
    if not challengeMapID then
        db.chars[key] = nil
        return
    end

    db.chars[key] = {
        mapID = challengeMapID,
        level = level,
        class = select(2, UnitClass("player")),
        -- The real item link, so other characters can show this key's own
        -- tooltip and shift-click it into chat. Nil if the key was not in
        -- the bags (bank), same limitation as the player's own line.
        link = FindKeystoneLink(),
    }
end

-- Every stored character except the one being played -- your own key already
-- has its own line, so repeating it in the list would be noise. Sorted by key
-- level, highest first, so the most interesting alt is nearest your own line.
local function GatherAlts()
    local db = ShowMyMythicKeystoneDB
    if not db or not db.chars then return {} end

    local selfKey = CharacterKey()
    local nameCounts = {}
    local rows = {}

    for key, entry in pairs(db.chars) do
        if key ~= selfKey and type(entry) == "table" and entry.mapID then
            local name, realm = key:match("^(.-)%-(.+)$")
            if name then
                nameCounts[name] = (nameCounts[name] or 0) + 1
                rows[#rows + 1] = {
                    name = name,
                    realm = realm,
                    mapID = entry.mapID,
                    level = entry.level or 0,
                    class = entry.class,
                    link = entry.link,
                }
            end
        end
    end

    -- The realm suffix is only informative when the same name exists twice, so
    -- by default it appears only then. Forcing it on is an option.
    local forceRealm = db.forceRealm
    for _, row in ipairs(rows) do
        row.showRealm = forceRealm or (nameCounts[row.name] or 0) > 1
    end

    table.sort(rows, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return a.name < b.name
    end)

    return rows
end

local function ClassColored(name, class)
    local colors = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not colors then return name end
    return ("|c%s%s|r"):format(colors.colorStr or "ffffffff", name)
end

-- One button per character, holding both lines, reused between refreshes; the
-- pool only ever grows to the largest list seen this session. A button rather
-- than bare font strings so the row can carry the keystone's own tooltip and
-- shift-click linking, exactly like the player's line. Mouse is only enabled
-- on rows that actually have a link, so a linkless row can never swallow a
-- click meant for the panel underneath.
local function AcquireAltRow(index)
    local row = altRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, altFrame)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.key = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetJustifyH("RIGHT")
    row.key:SetJustifyH("RIGHT")
    row.key:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.name:SetPoint("BOTTOMRIGHT", row.key, "TOPRIGHT", 0, ALT_LINE_GAP)

    row:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)

    row:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" or not self.link then return end
        if HandleModifiedItemClick(self.link) then return end
        if IsShiftKeyDown() then
            ChatEdit_InsertLink(self.link)
        end
    end)

    altRows[index] = row
    return row
end

-- Lay the list out from the bottom up, so it grows into the empty space above
-- rather than pushing down into the dungeon icons.
local function RefreshAlts()
    if not altFrame then return end

    local db = ShowMyMythicKeystoneDB
    if not db or db.hidden or not db.showAlts then
        altFrame:Hide()
        return
    end

    local rows = GatherAlts()
    if #rows == 0 then
        altFrame:Hide()
        return
    end

    local widest, offset = 0, 0
    for index, row in ipairs(rows) do
        local widgets = AcquireAltRow(index)

        local label = row.showRealm and (row.name .. "-" .. row.realm) or row.name
        widgets.name:SetText(ClassColored(label, row.class))

        local mapName = C_ChallengeMode.GetMapUIInfo(row.mapID)
        widgets.key:SetText(("|cffa335ee%s +%d|r"):format(mapName or "Keystone", row.level))

        widgets.link = row.link
        widgets:EnableMouse(row.link ~= nil)

        -- The button hugs its two lines exactly, so the mouse target is the
        -- text and nothing but the text.
        local width = math.max(widgets.name:GetStringWidth(), widgets.key:GetStringWidth())
        local height = widgets.key:GetStringHeight() + ALT_LINE_GAP + widgets.name:GetStringHeight()
        widgets:SetSize(math.max(width, 1), height)

        widgets:ClearAllPoints()
        widgets:SetPoint("BOTTOMRIGHT", altFrame, "BOTTOMRIGHT", 0, offset)
        offset = offset + height + ALT_ENTRY_GAP

        widgets:Show()
        widest = math.max(widest, width)
    end

    -- Anything left over from a longer list last time.
    for index = #rows + 1, #altRows do
        altRows[index]:Hide()
    end

    altFrame:SetWidth(math.max(widest, 1))
    altFrame:SetHeight(math.max(offset, 1))
    altFrame:Show()
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

    local yOffset = -320
    if panelTop and iconTop then
        yOffset = iconTop - panelTop + 36
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOP", ChallengesFrame, "TOP", 0, yOffset)

    -- The alt column shares the keystone line's baseline and grows upward from
    -- it. Horizontal placement is measured from ChallengesFrame's own edge for
    -- the same reason the keystone line is -- WeeklyInfo's bounds are not where
    -- its text draws, so it cannot be used as an anchor.
    --
    -- The +4: 2px because the keystone text is centered in a frame 4px taller
    -- than its string, so the string's bottom sits 2px above the frame's
    -- bottom; 2px more because the two fonts differ in size, and with equal
    -- string bottoms the small line still read as sitting low next to the
    -- large one in game (checked by eye, 2026-07-30).
    if altFrame then
        altFrame:ClearAllPoints()
        altFrame:SetPoint("BOTTOMRIGHT", ChallengesFrame, "TOPRIGHT",
            -ALT_RIGHT_INSET, yOffset - (frame:GetHeight() or 0) + 4)
    end
end

local function Refresh()
    -- The panel is load-on-demand, so another addon pulling it in early can
    -- attach us before our own ADDON_LOADED has built the DB.
    if not frame or not ShowMyMythicKeystoneDB then return end

    CheckWeeklyReset()
    RecordSelf()

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
        if altFrame then altFrame:Hide() end
        return
    end

    text:SetText(msg)
    frame:SetWidth(text:GetStringWidth() + 16)
    frame:SetHeight(text:GetStringHeight() + 4)
    -- Only take clicks when there is something to link, so the frame never
    -- swallows input meant for Blizzard's panel underneath.
    frame:EnableMouse(keystoneLink ~= nil)
    RefreshAlts()
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

    -- Text only, no backdrop and no border: the list is meant to read as part
    -- of the panel rather than as a window sitting on top of it.
    altFrame = CreateFrame("Frame", "ShowMyMythicKeystoneAltFrame", ChallengesFrame)
    altFrame:SetFrameStrata("HIGH")
    altFrame:SetFrameLevel(ChallengesFrame:GetFrameLevel() + 50)

    ChallengesFrame:HookScript("OnShow", Refresh)
    Refresh()
end

local function Print(msg)
    print("|cffa335eeShowMyMythicKeystone|r: " .. msg)
end

local function ClearStore()
    ShowMyMythicKeystoneDB.chars = {}
    RecordSelf()
    if frame then Refresh() end
end

--------------------------------------------------------------------------------
-- Options
--------------------------------------------------------------------------------

local function BuildOptions()
    if not (Settings and Settings.RegisterAddOnCategory and Settings.RegisterVerticalLayoutCategory) then
        return
    end

    local category, layout = Settings.RegisterVerticalLayoutCategory("Show My Mythic Keystone")

    local altsSetting = Settings.RegisterAddOnSetting(
        category,
        "SHOWMYMYTHICKEYSTONE_SHOW_ALTS",
        "showAlts",
        ShowMyMythicKeystoneDB,
        Settings.VarType.Boolean,
        "Enable alt's keystones",
        Settings.Default.True
    )
    Settings.CreateCheckbox(category, altsSetting,
        "List your other characters' keystones beside your own. Only characters you have played since the weekly reset appear.")
    Settings.SetOnValueChangedCallback("SHOWMYMYTHICKEYSTONE_SHOW_ALTS", function()
        if frame then Refresh() end
    end)

    local realmSetting = Settings.RegisterAddOnSetting(
        category,
        "SHOWMYMYTHICKEYSTONE_FORCE_REALM",
        "forceRealm",
        ShowMyMythicKeystoneDB,
        Settings.VarType.Boolean,
        "Force server name",
        Settings.Default.False
    )
    Settings.CreateCheckbox(category, realmSetting,
        "Always show the realm after a character's name. Off, it appears only when two characters share a name.")
    Settings.SetOnValueChangedCallback("SHOWMYMYTHICKEYSTONE_FORCE_REALM", function()
        if frame then Refresh() end
    end)

    -- NOT CreateSettingsButtonInitializer: its signature is not stable across
    -- client versions and it asserts on 12.0 (same finding recorded in
    -- MythicDungeonTools_NextPullTracker's SettingsPullColors.lua). The
    -- element initializer it wraps builds fine, so build that directly.
    -- pcall, because an error escaping here killed the checkboxes AND the
    -- rest of the login handler once already. /smk clear always works.
    if layout and Settings.CreateElementInitializer then
        local ok, initializer = pcall(Settings.CreateElementInitializer,
            "SettingButtonControlTemplate", {
                name = "Saved keystones",
                buttonText = "Clear saved variables",
                buttonClick = ClearStore,
                tooltip = "Forget every stored character. The list rebuilds as you play them again.",
            })
        if ok and initializer then
            pcall(layout.AddInitializer, layout, initializer)
        end
    end

    Settings.RegisterAddOnCategory(category)
end

SLASH_SHOWMYMYTHICKEYSTONE1 = "/showmymythickeystone"
SLASH_SHOWMYMYTHICKEYSTONE2 = "/smk"
SlashCmdList.SHOWMYMYTHICKEYSTONE = function(msg)
    local cmd = msg:lower():match("^(%S*)")

    if cmd == "show" then
        ShowMyMythicKeystoneDB.hidden = false
    elseif cmd == "hide" then
        ShowMyMythicKeystoneDB.hidden = true
    elseif cmd == "alts" then
        ShowMyMythicKeystoneDB.showAlts = not ShowMyMythicKeystoneDB.showAlts
        Refresh()
        Print(ShowMyMythicKeystoneDB.showAlts and "alt keystones shown." or "alt keystones hidden.")
        return
    elseif cmd == "clear" then
        ClearStore()
        Print("stored keystones cleared.")
        return
    elseif cmd == "" or cmd == "toggle" then
        ShowMyMythicKeystoneDB.hidden = not ShowMyMythicKeystoneDB.hidden
    else
        Print("/smk show, /smk hide, /smk alts, /smk clear, or /smk on its own to toggle.")
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
            ShowMyMythicKeystoneDB = ShowMyMythicKeystoneDB or {}
            local db = ShowMyMythicKeystoneDB
            if db.hidden == nil then db.hidden = false end
            if db.showAlts == nil then db.showAlts = true end
            if db.forceRealm == nil then db.forceRealm = false end
            db.chars = db.chars or {}
        elseif addonName == "Blizzard_ChallengesUI" then
            AttachToChallengesFrame()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_LOGIN" then
        -- Populates the challenge-mode map names GetMapUIInfo reads from.
        C_MythicPlus.RequestMapInfo()

        -- Drop last week's rows before anything reads them, then record this
        -- character even if the panel is never opened this session.
        CheckWeeklyReset()
        RecordSelf()

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
        watcher:SetScript("OnEvent", function()
            -- Keep the store current even with the panel shut, so logging out
            -- on an alt leaves a correct row behind.
            CheckWeeklyReset()
            RecordSelf()
            if frame then Refresh() end
        end)

        -- Last on purpose: the settings API has shifted between client builds
        -- before, and when it threw from earlier in this handler it silently
        -- took the watcher registration above down with it.
        BuildOptions()

        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
