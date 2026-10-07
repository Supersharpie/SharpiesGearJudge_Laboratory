local addonName, SGF = ... 
local L = (_G.MSC and _G.MSC.L) or setmetatable({}, { __index = function(t, k) return k end })
SGF.LabItems = { [1]={}, [2]={} }
SGF.ActiveSet = 1 -- Which set is currently receiving inputs?
SGF.StatRows = {}
-- Each set's scoring profile: nil follows the main addon; "P:<profile key>",
-- "R:<leveling role>" or "B:<Talents build id>" pick one for that set
SGF.SetProfiles = {}
SGF.LookLevel = nil -- Level the sets are scored at; nil = your own level
SGF.Results = {}

-- [[ TEXTURE MAP ]]
SGF.SlotTextures = {
    HeadSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Head",
    NeckSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Neck",
    ShoulderSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Shoulder",
    BackSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest", 
    ChestSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Chest",
    WristSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Wrists",
    HandsSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Hands",
    WaistSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Waist",
    LegsSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Legs",
    FeetSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Feet",
    Finger0Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger",
    Finger1Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Finger",
    Trinket0Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket",
    Trinket1Slot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Trinket",
    MainHandSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-MainHand",
    SecondaryHandSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-SecondaryHand",
    RangedSlot = "Interface\\Paperdoll\\UI-PaperDoll-Slot-Ranged",
}

-- Ordered list for the UI columns
SGF.OrderedSlots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

-- [[ 2. SMART ITEM HANDLERS ]]
function SGF.GetSlotFromLoc(equipLoc, currentItems)
    if not equipLoc then return nil end
    
    if equipLoc == "INVTYPE_HEAD" then return "HeadSlot" end
    if equipLoc == "INVTYPE_NECK" then return "NeckSlot" end
    if equipLoc == "INVTYPE_SHOULDER" then return "ShoulderSlot" end
    if equipLoc == "INVTYPE_CLOAK" then return "BackSlot" end
    if equipLoc == "INVTYPE_CHEST" or equipLoc == "INVTYPE_ROBE" then return "ChestSlot" end
    if equipLoc == "INVTYPE_WRIST" then return "WristSlot" end
    if equipLoc == "INVTYPE_HAND" then return "HandsSlot" end
    if equipLoc == "INVTYPE_WAIST" then return "WaistSlot" end
    if equipLoc == "INVTYPE_LEGS" then return "LegsSlot" end
    if equipLoc == "INVTYPE_FEET" then return "FeetSlot" end
    
    if equipLoc == "INVTYPE_FINGER" then 
        if not currentItems["Finger0Slot"] then return "Finger0Slot" else return "Finger1Slot" end
    end
    if equipLoc == "INVTYPE_TRINKET" then 
        if not currentItems["Trinket0Slot"] then return "Trinket0Slot" else return "Trinket1Slot" end
    end
    
    if equipLoc == "INVTYPE_2HWEAPON" or equipLoc == "INVTYPE_WEAPONMAINHAND" then return "MainHandSlot" end
    if equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_WEAPONOFFHAND" or equipLoc == "INVTYPE_HOLDABLE" then return "SecondaryHandSlot" end
    
    if equipLoc == "INVTYPE_WEAPON" then
        if not currentItems["MainHandSlot"] then return "MainHandSlot" end
        local mhLink = currentItems["MainHandSlot"]
        local _, _, _, _, _, _, _, _, mhLoc = GetItemInfo(mhLink)
        if mhLoc == "INVTYPE_2HWEAPON" then return "MainHandSlot" end
        if not currentItems["SecondaryHandSlot"] then return "SecondaryHandSlot" end
        return "MainHandSlot"
    end
    
    if equipLoc == "INVTYPE_RANGED" or equipLoc == "INVTYPE_THROWN" or equipLoc == "INVTYPE_RANGEDRIGHT" or equipLoc == "INVTYPE_RELIC" then return "RangedSlot" end
    return nil
end

function SGF.ReceiveLink(link)
    if not link then return end
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
    if not equipLoc then 
        local itemID = link:match("item:(%d+)")
        if itemID then _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID) end
    end

    if not equipLoc then return end

    -- USE ACTIVE SET
    local setIdx = SGF.ActiveSet
    local currentItems = SGF.LabItems[setIdx]
    
    local targetSlot = SGF.GetSlotFromLoc(equipLoc, currentItems)
    
    if targetSlot then
        SGF.LabItems[setIdx][targetSlot] = link
        SGF.UpdateLabSlot(targetSlot, setIdx)
        
        -- Traffic Cop (2H vs Offhand)
        if targetSlot == "MainHandSlot" and equipLoc == "INVTYPE_2HWEAPON" then
            if SGF.LabItems[setIdx]["SecondaryHandSlot"] then
                SGF.LabItems[setIdx]["SecondaryHandSlot"] = nil
                SGF.UpdateLabSlot("SecondaryHandSlot", setIdx)
                print(string.format(L["|cffff0000SGJ (Set %d):|r Removed Off-Hand (2H Weapon equipped)."], setIdx))
            end
        elseif targetSlot == "SecondaryHandSlot" then
            local mhLink = SGF.LabItems[setIdx]["MainHandSlot"]
            if mhLink then
                local _, _, _, _, _, _, _, _, mhLoc = GetItemInfo(mhLink)
                if mhLoc == "INVTYPE_2HWEAPON" then
                    SGF.LabItems[setIdx]["MainHandSlot"] = nil
                    SGF.UpdateLabSlot("MainHandSlot", setIdx)
                    print(string.format(L["|cffff0000SGJ (Set %d):|r Removed Main-Hand (Cannot hold 2H with Shield)."], setIdx))
                end
            end
        end

        SGF.CalculateLabScore()
        PlaySound(1115) 
    else
        print(string.format(L["|cffff0000SGJ:|r Cannot slot item type: %s"], equipLoc or L["Unknown"]))
    end
end

-- [[ 3. DISPLAY LOGIC ]] 
function SGF.UpdateLabSlot(slotName, setIdx)
    local MSC = _G.MSC 
    if not MSC or not MSC.ViewLaboratory then return end
    
    local btn = MSC.ViewLaboratory.Slots[setIdx][slotName]
    local link = SGF.LabItems[setIdx][slotName]
    
    if link then
        btn.Icon:SetTexture(GetItemIcon(link))
        btn.link = link
    else
        local bgTexture = SGF.SlotTextures[slotName] or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest"
        btn.Icon:SetTexture(bgTexture)
        btn.link = nil
    end
end

function SGF.ImportEquipped()
    local MSC = _G.MSC
    if not MSC or not MSC.ViewLaboratory then return end
    
    local setIdx = SGF.ActiveSet -- Import into active set

    for _, slotName in ipairs(SGF.OrderedSlots) do
        local slotID = GetInventorySlotInfo(slotName)
        local link = GetInventoryItemLink("player", slotID)
        SGF.LabItems[setIdx][slotName] = link
        SGF.UpdateLabSlot(slotName, setIdx)
    end
    SGF.CalculateLabScore()
    print(string.format(L["|cff00ff00SGJ:|r Equipped gear imported into Set %d"], setIdx))
end

function SGF.CopySet1To2()
    -- Deep copy table
    SGF.LabItems[2] = {}
    for k, v in pairs(SGF.LabItems[1]) do
        SGF.LabItems[2][k] = v
    end
    -- Update UI
    for _, slotName in ipairs(SGF.OrderedSlots) do
        SGF.UpdateLabSlot(slotName, 2)
    end
    SGF.CalculateLabScore()
    print(L["|cff00ff00SGJ:|r Copied Set 1 to Set 2."])
end

function SGF.ClearLab(setIdx)
    -- If setIdx is nil, clear BOTH. Otherwise clear specific.
    if not setIdx then
        SGF.LabItems = { [1]={}, [2]={} }
        for _, s in ipairs(SGF.OrderedSlots) do 
            SGF.UpdateLabSlot(s, 1)
            SGF.UpdateLabSlot(s, 2)
        end
    else
        SGF.LabItems[setIdx] = {}
        for _, s in ipairs(SGF.OrderedSlots) do SGF.UpdateLabSlot(s, setIdx) end
    end
    
    SGF.CalculateLabScore()
    local MSC = _G.MSC
    if MSC and MSC.ViewLaboratory then
        MSC.ViewLaboratory.NameInput:SetText("")
        UIDropDownMenu_SetText(MSC.ViewLaboratory.LoadDD, L["Load Set..."])
    end
end

-- [[ 2.5 SCENARIO ENGINE ]]
-- Each set is scored with its own profile, at the look-ahead level, with its
-- enchants as linked or the best available. Weights for another level are
-- rebuilt from the class's leveling data with that level passed in; the game's
-- UnitLevel is never replaced (writing that global would taint it for
-- Blizzard's own code).
SGF.SlotIDs = {
    HeadSlot=1, NeckSlot=2, ShoulderSlot=3, BackSlot=15, ChestSlot=5,
    WristSlot=9, HandsSlot=10, WaistSlot=6, LegsSlot=7, FeetSlot=8,
    Finger0Slot=11, Finger1Slot=12, Trinket0Slot=13, Trinket1Slot=14,
    MainHandSlot=16, SecondaryHandSlot=17, RangedSlot=18
}
-- Slots the Receipt counts as missing an enchant when empty of one
local ENCHANT_SLOTS = { [1]=true, [3]=true, [5]=true, [7]=true, [8]=true, [9]=true, [10]=true, [15]=true, [16]=true, [17]=true }

function SGF.MaxLevel()
    local MSC = _G.MSC
    return (MSC and MSC.IsTBC) and 70 or 60
end

function SGF.GetLookLevel()
    return SGF.LookLevel or UnitLevel("player") or 1
end

-- Lab options kept across sessions (enchant view)
function SGF.GetOptions()
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    SGJ_LaboratoryDB.Options = SGJ_LaboratoryDB.Options or {}
    return SGJ_LaboratoryDB.Options
end

-- "Leveling_Tank_21_40" -> "Leveling_Tank", 21, 40
local function ParseBand(key)
    local role, lo, hi = string.match(key or "", "^(.-)_(%d+)_(%d+)$")
    if role then return role, tonumber(lo), tonumber(hi) end
end

-- The role's band that holds the level; outside every band, the nearest one
-- below it (or the first band)
local function FindBand(rows, role, level)
    if not rows or not role then return nil end
    local below, belowLo, first, firstLo
    for k in pairs(rows) do
        local r, lo, hi = ParseBand(k)
        if r == role then
            if level >= lo and level <= hi then return k end
            if lo <= level and (not belowLo or lo > belowLo) then below, belowLo = k, lo end
            if not firstLo or lo < firstLo then first, firstLo = k, lo end
        end
    end
    return below or first
end

-- Raw weights for a profile key at a level, and the key they belong to
local function RawAtLevel(key, level)
    local MSC = _G.MSC
    local cls = MSC.CurrentClass
    if not cls or not key then return nil, key end
    local role = ParseBand(key)

    -- TBC leveling brackets slide from Start to End across the bracket
    if role and cls.LevelingBrackets and cls.LevelingBrackets[key] then
        local k = FindBand(cls.LevelingBrackets, role, level) or key
        local b = cls.LevelingBrackets[k]
        local t = (b.max and b.min and b.max > b.min) and (level - b.min) / (b.max - b.min) or 0
        t = math.max(0, math.min(1, t))
        local out = {}
        for s in pairs(b.Start or {}) do out[s] = true end
        for s in pairs(b.End or {}) do out[s] = true end
        for s in pairs(out) do
            local a, e = (b.Start and b.Start[s]) or 0, (b.End and b.End[s]) or 0
            out[s] = math.max(0, a + (e - a) * t)
        end
        return out, k
    end

    -- Forever / Era leveling rows; Forever reads the per-spec curve at the level
    if role and cls.LevelingWeights and cls.LevelingWeights[key] then
        local rows = cls.LevelingWeights
        local k = FindBand(rows, role, level) or key
        local _, _, hi = ParseBand(k)
        -- A chain that changes name (Paladin 41-51 -> Ret 52-59)
        while hi and level > hi and cls.LevelingNext and cls.LevelingNext[k] and rows[cls.LevelingNext[k]] do
            k = cls.LevelingNext[k]; _, _, hi = ParseBand(k)
        end
        if MSC.IsForever and MSC.EvaluateLevelingCurve then
            local r = ParseBand(k)
            local curves = cls.LevelingCurves
            local curve = curves and (curves[r] or (MSC.LevelingCurveAlias and curves[MSC.LevelingCurveAlias[r] or ""]))
            if curve then return MSC.EvaluateLevelingCurve(curve, level), k end
        end
        return rows[k], k
    end

    -- Raid, custom and other profiles don't change with level
    local raw, specKey, mathSpec = MSC:LookupRawWeights(key)
    return raw, mathSpec or specKey or key
end

-- Leveling rows of the class (Forever/Era LevelingWeights, TBC LevelingBrackets)
local function LevelingRows()
    local cls = _G.MSC.CurrentClass
    return cls and (cls.LevelingBrackets or cls.LevelingWeights)
end

-- Weights for a set: its own profile at the look-ahead level.
-- Returns weights, profile key.
function SGF.ResolveWeights(setIdx, level)
    local MSC = _G.MSC
    local cls = MSC.CurrentClass
    local myLevel = UnitLevel("player") or 1
    level = level or SGF.GetLookLevel()
    local sel = SGF.SetProfiles[setIdx]
    local key

    if not sel then
        local w, k = MSC.GetCurrentWeights()
        if level == myLevel or not k then return w, k end
        key = k
        -- At 60 a Talents build's raid profile takes over, as in the main addon
        local endgame = MSC.TalentBuildRole and MSC.TalentBuildRole.endgame
        if level >= 60 and endgame and cls and cls.Weights and cls.Weights[endgame] and ParseBand(key) then key = endgame end
    else
        local kind, val = sel:match("^(%a):(.+)$")
        if kind == "P" then
            key = val
        elseif kind == "R" then
            key = FindBand(LevelingRows(), val, level)
        elseif kind == "B" then
            local b = _G.SGJ_Talents and _G.SGJ_Talents.Builds and _G.SGJ_Talents.Builds[val]
            if b then
                if level >= 60 and b.endgame and cls and cls.Weights and cls.Weights[b.endgame] then
                    key = b.endgame
                else
                    key = FindBand(LevelingRows(), b.leveling or "Leveling", level) or FindBand(LevelingRows(), "Leveling", level)
                end
            end
        end
    end

    if not key then return MSC.GetCurrentWeights() end
    local raw, k = RawAtLevel(key, level)
    if not raw then return MSC.GetCurrentWeights() end
    local w = MSC:ApplyWeightPipeline(raw, k)
    return w, k
end

-- A leveling role's name without its level range ("Leveling: Tank (21-40)" -> "Leveling: Tank")
local function RoleLabel(role)
    local MSC = _G.MSC
    local names = MSC.CurrentClass and MSC.CurrentClass.PrettyNames
    local key = FindBand(LevelingRows(), role, UnitLevel("player") or 1)
    local name = key and names and names[key]
    if name then return (name:gsub("%s*%(%d+%s*%-%s*%d+%)%s*$", "")) end
    return role
end

function SGF.ProfileLabel(sel)
    local MSC = _G.MSC
    if not sel then return L["Follow Main Addon"] end
    local kind, val = sel:match("^(%a):(.+)$")
    if kind == "P" then
        return (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[val]) or val
    elseif kind == "R" then
        return RoleLabel(val)
    elseif kind == "B" then
        local b = _G.SGJ_Talents and _G.SGJ_Talents.Builds and _G.SGJ_Talents.Builds[val]
        return b and b.name and ((MSC.ClassL and MSC.ClassL(b.class, b.name)) or L[b.name]) or val
    end
    return sel
end

-- Dropdown entries: Talents builds, leveling roles, then raid and custom profiles
function SGF.ProfileChoices()
    local MSC = _G.MSC
    local cls = MSC.CurrentClass
    local out = {}
    local _, myClass = UnitClass("player")

    local T = _G.SGJ_Talents
    if T and T.BuildList then
        local builds = {}
        for _, b in ipairs(T.BuildList) do
            if b.class == myClass then table.insert(builds, { text = (MSC.ClassL and MSC.ClassL(b.class, b.name)) or L[b.name], sel = "B:" .. b.id }) end
        end
        if #builds > 0 then
            table.insert(out, { text = L["Talent Builds"], title = true })
            for _, e in ipairs(builds) do table.insert(out, e) end
        end
    end

    local rows = LevelingRows()
    if rows then
        -- A role made only of chain continuations (Paladin's Ret 52-59) is part of another role
        local continues = {}
        for _, nextKey in pairs((cls and cls.LevelingNext) or {}) do continues[nextKey] = true end
        local own = {}
        for k in pairs(rows) do
            local r = ParseBand(k)
            if r and not continues[k] then own[r] = true end
        end
        local seen, roles = {}, {}
        for k in pairs(rows) do
            local r = ParseBand(k)
            if r and own[r] and not seen[r] then seen[r] = true; table.insert(roles, { text = RoleLabel(r), sel = "R:" .. r }) end
        end
        table.sort(roles, function(a, b) return a.text < b.text end)
        if #roles > 0 then
            table.insert(out, { text = L["Leveling Roles"], title = true })
            for _, e in ipairs(roles) do table.insert(out, e) end
        end
    end

    local profiles, seen = {}, {}
    local function AddKey(k)
        if seen[k] then return end
        seen[k] = true
        table.insert(profiles, { text = SGF.ProfileLabel("P:" .. k), sel = "P:" .. k })
    end
    if cls and cls.Weights then for k in pairs(cls.Weights) do AddKey(k) end end
    if SharpiesGearJudgeDB and SharpiesGearJudgeDB.customWeights then
        for k in pairs(SharpiesGearJudgeDB.customWeights) do AddKey(k) end
    end
    table.sort(profiles, function(a, b) return a.text < b.text end)
    if #profiles > 0 then
        table.insert(out, { text = L["Profiles"], title = true })
        for _, e in ipairs(profiles) do table.insert(out, e) end
    end
    return out
end

-- Runs fn with the main addon's enchant setting switched (1 = none, 3 = best).
-- The setting is part of the scorer's cache key, so nothing cached goes stale.
local function WithEnchantMode(mode, fn, ...)
    local s = SGJ_Settings
    if not s then return fn(...) end
    local old = s.EnchantMode
    s.EnchantMode = mode
    local ok, a, b = pcall(fn, ...)
    s.EnchantMode = old
    if not ok then error(a, 0) end
    return a, b
end

local function EnchantOf(link)
    return tonumber(link and link:match("item:%d+:(%d+)") or 0) or 0
end

-- Score with each item's own enchant (the main addon's "Current" setting would
-- use the enchant on YOUR equipped item in that slot instead)
local function ScoreLinked(gear, w, key)
    local MSC = _G.MSC
    local score, stats = MSC:GetTotalCharacterScore(gear, w, key)
    stats = stats or {}
    for _, link in pairs(gear) do
        local data = MSC.EnchantDB and MSC.EnchantDB[EnchantOf(link)]
        if data and data.stats then
            score = score + (MSC.GetItemScore(data.stats, w) or 0)
            for s, v in pairs(data.stats) do stats[s] = (stats[s] or 0) + v end
        end
    end
    return score, stats
end

local function ScoreBest(gear, w, key)
    return _G.MSC:GetTotalCharacterScore(gear, w, key)
end

local function HitRating(t, spellOnly)
    if not t then return 0 end
    local MSC = _G.MSC
    if spellOnly and not MSC.IsForever then return t["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0 end
    return (t["ITEM_MOD_HIT_RATING_SHORT"] or 0) + (t["ITEM_MOD_HIT_SPELL_RATING_SHORT"] or 0)
        + (t["ITEM_MOD_HIT_MELEE_RATING_SHORT"] or 0) + (t["ITEM_MOD_HIT_RANGED_RATING_SHORT"] or 0)
end

local function EquippedGear()
    local gear = {}
    for _, id in pairs(SGF.SlotIDs) do gear[id] = GetInventoryItemLink("player", id) end
    return gear
end

-- Hit and defense for a set: your live values (talents, race and buffs
-- included) plus the difference between the set's gear and what you wear
local function CapLines(stats, liveStats, key, level)
    local MSC = _G.MSC
    local lines = {}
    local _, class = UnitClass("player")
    local role = MSC.GetRingRole and MSC.GetRingRole(class, key) or "melee"
    local myLevel = UnitLevel("player") or 1
    local lvl = math.min(level, SGF.MaxLevel())

    -- The table's low-level rows are missing or zero (level 8 is all zeros):
    -- use the first level at or above this one that has a real value
    local function TBCScalar(statKey)
        local idx = MSC.RatingIndexMap and MSC.RatingIndexMap[statKey]
        local t = MSC.CombatRatingScalars
        if idx and t then
            for l = math.max(1, math.min(lvl, 70)), 70 do
                local v = t[l] and t[l][idx]
                if v and v > 0 then return v end
            end
        end
        return 15.8
    end

    if role == "melee" or role == "hunter" or role == "caster" then
        local spell = (role == "caster")
        local kind = spell and "SPELL" or ((class == "HUNTER" and not tostring(key or ""):upper():find("MELEE")) and "RANGED" or "MELEE")
        local delta = HitRating(stats, spell) - HitRating(liveStats, spell)
        local cur, target
        if MSC.IsForever then
            cur = MSC:GetForeverHitPercent(kind) + delta / 10 -- 10 Hit Rating = 1% at every level
            target = MSC.GetForeverCapTarget(spell and "SPELL" or "MELEE", level)
        else
            local live = spell and (GetSpellHitModifier and GetSpellHitModifier() or 0) or (GetHitModifier and GetHitModifier() or 0)
            if MSC.IsTBC then
                local cr = spell and 8 or (kind == "RANGED" and 7 or 6)
                live = live + (GetCombatRatingBonus and GetCombatRatingBonus(cr) or 0)
                cur = live + delta / TBCScalar(spell and "ITEM_MOD_HIT_SPELL_RATING_SHORT" or "ITEM_MOD_HIT_RATING_SHORT")
            else
                cur = live + delta -- Era gear gives hit in percent
            end
            target = spell and 16 or 9
        end
        table.insert(lines, { label = spell and L["Spell Hit"] or L["Hit"], cur = cur, target = target, pct = true })
    end

    if role == "tank" then
        local base, mod = UnitDefense("player")
        local live = (MSC.SanitizeStat and (MSC.SanitizeStat(base) + MSC.SanitizeStat(mod))) or ((base or 0) + (mod or 0))
        local dKey = "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"
        local delta = ((stats and stats[dKey]) or 0) - ((liveStats and liveStats[dKey]) or 0)
        local scalar = MSC.IsTBC and TBCScalar(dKey) or 1 -- Forever: 1 rating = 1 skill; Era gear gives skill
        local cur = live + math.floor(delta / scalar) + 5 * (lvl - math.min(myLevel, SGF.MaxLevel()))
        local target
        if MSC.IsForever then target = MSC.GetForeverDefenseTarget(level) else target = lvl * 5 + 140 end
        table.insert(lines, { label = L["Defense"], cur = cur, target = target })
    end
    return lines
end

-- "Hit 7.2/9% -1.8": red below the target, green at it, yellow more than 1% past it
local function FormatCap(c)
    local function Num(v) return c.pct and string.format("%.1f", v) or string.format("%d", v) end
    local unit = c.pct and "%" or ""
    if not c.target or c.target <= 0 then
        return string.format("|cffaaaaaa%s %s%s|r", c.label, Num(c.cur), unit)
    end
    local tgt = c.pct and string.format("%g", math.floor(c.target * 10 + 0.5) / 10) or string.format("%d", c.target)
    local gap = c.cur - c.target
    local color = "55ff55"
    if gap < -(c.pct and 0.05 or 0.5) then color = "ff5555"
    elseif c.pct and gap > 1 then color = "ffd100" end
    local tail = (math.abs(gap) >= (c.pct and 0.05 or 0.5)) and (" " .. (gap > 0 and "+" or "-") .. Num(math.abs(gap))) or ""
    return string.format("|cff%s%s %s/%s%s%s|r", color, c.label, Num(c.cur), tgt, unit, tail)
end

-- Scores one set. Returns { score, stats, key, slots = {slotName = score}, missing, enchGain, caps }
local oneItem = {}
function SGF.EvaluateSet(idx, level)
    local MSC = _G.MSC
    local w, key = SGF.ResolveWeights(idx, level)
    if not w then return nil end
    local bestView = (SGF.GetOptions().EnchantView == "best")
    local scorer = bestView and ScoreBest or ScoreLinked
    local mode = bestView and 3 or 1

    local gear = {}
    for sName, link in pairs(SGF.LabItems[idx]) do
        if link and SGF.SlotIDs[sName] then gear[SGF.SlotIDs[sName]] = link end
    end

    -- Set bonuses are scored from a shared table; fill it with this set's weights
    if MSC.UpdateSetBonusScores then MSC:UpdateSetBonusScores(w) end

    local r = { key = key, slots = {}, missing = 0 }
    r.score, r.stats = WithEnchantMode(mode, scorer, gear, w, key)
    local linked = bestView and WithEnchantMode(1, ScoreLinked, gear, w, key) or r.score
    local best = bestView and r.score or WithEnchantMode(3, ScoreBest, gear, w, key)
    r.enchGain = (best or 0) - (linked or 0)

    -- Hit past a cap is worth less (Forever: the same correction tooltips use).
    -- That correction is built from your own level's hit cap, so it is left
    -- out when the sets are scored at another level.
    local _, liveStats = WithEnchantMode(mode, scorer, EquippedGear(), w, key)
    local atOwnLevel = math.min(level, SGF.MaxLevel()) == math.min(UnitLevel("player") or 1, SGF.MaxLevel())
    if MSC.IsForever and MSC.ForeverHitCapCorrection and next(gear) and atOwnLevel then
        local correction = MSC.ForeverHitCapCorrection(w, HitRating(liveStats), HitRating(r.stats))
        r.score = r.score + (correction or 0)
    end
    r.caps = next(gear) and CapLines(r.stats, liveStats, key, level) or {}

    for sName, slotID in pairs(SGF.SlotIDs) do
        local link = SGF.LabItems[idx][sName]
        if link then
            wipe(oneItem); oneItem[slotID] = link
            r.slots[sName] = WithEnchantMode(mode, scorer, oneItem, w, key) or 0
            local _, _, _, _, _, _, _, _, loc = GetItemInfo(link)
            if ENCHANT_SLOTS[slotID] and loc ~= "INVTYPE_HOLDABLE" and EnchantOf(link) == 0 then r.missing = r.missing + 1 end
        end
    end
    r.weights = w
    return r
end

-- Item score on each slot; items above the scoring level are tinted red
function SGF.RefreshSlotMarks(setIdx)
    local MSC = _G.MSC
    local view = MSC and MSC.ViewLaboratory
    if not view or not view.Slots then return end
    local res = SGF.Results[setIdx]
    local level = SGF.GetLookLevel()
    for sName, btn in pairs(view.Slots[setIdx]) do
        local link = SGF.LabItems[setIdx][sName]
        if link then
            local s = res and res.slots[sName]
            btn.ScoreText:SetText(s and string.format("%.0f", s) or "")
            local req = select(5, GetItemInfo(link))
            btn.TooHigh = (req and req > level) and req or nil
            if btn.TooHigh then btn.Icon:SetVertexColor(1, 0.3, 0.3) else btn.Icon:SetVertexColor(1, 1, 1) end
        else
            btn.ScoreText:SetText("")
            btn.TooHigh = nil
            btn.Icon:SetVertexColor(1, 1, 1)
        end
    end
end

function SGF.CalculateLabScore()
    local MSC = _G.MSC
    if not MSC or not MSC.ViewLaboratory or not MSC.ViewLaboratory.ScoreVal1 then return end
    local view = MSC.ViewLaboratory
    local level = SGF.GetLookLevel()

    for idx = 1, 2 do
        SGF.Results[idx] = SGF.EvaluateSet(idx, level)
        if view.ProfileDD and view.ProfileDD[idx] then UIDropDownMenu_SetText(view.ProfileDD[idx], SGF.ProfileLabel(SGF.SetProfiles[idx])) end
    end
    -- Give the shared set-bonus table back to the main addon's own weights
    if MSC.UpdateSetBonusScores then MSC:UpdateSetBonusScores((MSC.GetCurrentWeights())) end

    local r1, r2 = SGF.Results[1], SGF.Results[2]
    local s1, s2 = r1 and r1.score or 0, r2 and r2.score or 0
    view.ScoreVal1:SetText(string.format("%.1f", s1))
    view.ScoreVal2:SetText(string.format("%.1f", s2))

    -- Hit/defense and enchant lines under each set
    for idx = 1, 2 do
        local r, info = SGF.Results[idx], view.SetInfo and view.SetInfo[idx]
        if info then
            local hasItems = next(SGF.LabItems[idx]) ~= nil
            for i = 1, 2 do
                local c = hasItems and r and r.caps[i]
                info.Cap[i]:SetText(c and FormatCap(c) or "")
            end
            if hasItems and r then
                if r.missing > 0 then
                    info.Ench:SetText(string.format(L["|cffffd100%d unenchanted|r (%+.1f)"], r.missing, r.enchGain))
                elseif r.enchGain > 0.05 then
                    info.Ench:SetText(string.format(L["|cffaaaaaaBetter enchants: %+.1f|r"], r.enchGain))
                else
                    info.Ench:SetText(L["|cff55ff55Enchants: best|r"])
                end
            else
                info.Ench:SetText("")
            end
        end
        SGF.RefreshSlotMarks(idx)
    end

    -- Totals from two different profiles aren't on the same scale
    if r1 and r2 and r1.key ~= r2.key and next(SGF.LabItems[1]) and next(SGF.LabItems[2]) then
        view.DiffVal:SetText(L["|cffffd100Different profiles:|r compare the item scores"])
    else
        local diff = s2 - s1
        if diff > 0.1 then
            view.DiffVal:SetText(string.format(L["Set 2 is |cff00ff00+%.1f|r better"], diff))
        elseif diff < -0.1 then
            view.DiffVal:SetText(string.format(L["Set 1 is |cff00ff00+%.1f|r better"], math.abs(diff)))
        else
            view.DiffVal:SetText(L["|cff888888Sets are Equal|r"])
        end
    end

    SGF.UpdateStatList(r1 and r1.stats or {}, r2 and r2.stats or {}, (SGF.Results[SGF.ActiveSet] or r1 or {}).weights or {})
end

-- Recalculate once a slider stops moving
function SGF.QueueRecalc()
    if SGF.RecalcPending then return end
    SGF.RecalcPending = true
    C_Timer.After(0.15, function() SGF.RecalcPending = nil; SGF.CalculateLabScore() end)
end

-- Stat comparison columns, measured from the right edge of each row (headings in InitLaboratoryView use the same values)
SGF.STAT_COL_W = 34
SGF.STAT_COL_DIFF = -2
SGF.STAT_COL_V2 = -38
SGF.STAT_COL_V1 = -74
local STAT_NAME_RIGHT = -110

function SGF.UpdateStatList(stats1, stats2, weights)
    local MSC = _G.MSC
    local scrollFrame = MSC.ViewLaboratory.StatScroll
    local content = scrollFrame.Content

    -- Rows stretch with the content, which follows the scroll frame's width (OnSizeChanged in InitLaboratoryView)
    local scrollW = scrollFrame:GetWidth()
    if scrollW and scrollW > 50 then content:SetWidth(scrollW) end

    for _, row in ipairs(SGF.StatRows) do row:Hide() end

    local allKeys = {}
    for k, _ in pairs(stats1) do allKeys[k] = true end
    for k, _ in pairs(stats2) do allKeys[k] = true end

    local data = {}
    for statKey, _ in pairs(allKeys) do
        local w = weights[statKey] or 0
        local v1 = stats1[statKey] or 0
        local v2 = stats2[statKey] or 0
        if w > 0 or v1 > 0 or v2 > 0 then
            table.insert(data, { key=statKey, weight=w, v1=v1, v2=v2, isWeighted=(w>0) })
        end
    end

    table.sort(data, function(a,b)
        if a.isWeighted ~= b.isWeighted then return a.isWeighted end
        if a.isWeighted then return a.weight > b.weight else return a.key < b.key end
    end)

    local function Cell(row, rightOff)
        local t = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        t:SetPoint("RIGHT", row, "RIGHT", rightOff, 0); t:SetWidth(SGF.STAT_COL_W); t:SetJustifyH("RIGHT")
        return t
    end

    local yOff = 0
    for i, d in ipairs(data) do
        local row = SGF.StatRows[i]
        if not row then
            row = CreateFrame("Frame", nil, content)
            row:SetHeight(16)

            row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.Name:SetPoint("LEFT", 2, 0)
            row.Name:SetPoint("RIGHT", row, "RIGHT", STAT_NAME_RIGHT, 0)
            row.Name:SetJustifyH("LEFT")
            row.Name:SetWordWrap(false)

            row.V1 = Cell(row, SGF.STAT_COL_V1)
            row.V2 = Cell(row, SGF.STAT_COL_V2)
            row.Diff = Cell(row, SGF.STAT_COL_DIFF)

            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetColorTexture(1, 1, 1, 0.03)
            SGF.StatRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOff)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOff)
        row:Show()

        local cleanName = MSC.GetCleanStatName(d.key)
        cleanName = cleanName:gsub(" Rating", ""):gsub(" Spell", ""):gsub("Defense", "Def"):gsub("Attack Power", "AP")
        row.Name:SetText(cleanName)

        -- Color weighted stats
        if d.isWeighted then row.Name:SetTextColor(1, 0.82, 0) else row.Name:SetTextColor(0.6, 0.6, 0.6) end

        -- Calculate Diff
        local diff = d.v2 - d.v1
        local diffText = ""
        if diff > 0.01 then diffText = "|cff00ff00+"..string.format("%.0f", diff).."|r"
        elseif diff < -0.01 then diffText = "|cffff0000"..string.format("%.0f", diff).."|r"
        else diffText = "|cff888888-|r"
        end

        row.V1:SetText(string.format("%.0f", d.v1))
        row.V2:SetText(string.format("%.0f", d.v2))
        row.Diff:SetText(diffText)

        if i % 2 == 0 then row.bg:Show() else row.bg:Hide() end

        yOff = yOff - 18
    end

    content:SetHeight(math.max(1, math.abs(yOff)))
    if MSC.ViewLaboratory.StatEmpty then MSC.ViewLaboratory.StatEmpty:SetShown(#data == 0) end
end

-- [[ 4. SAVE / LOAD / DELETE / EXPORT ]]
function SGF.GetCharDB()
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    -- Full name (WoW Forever names have two parts; UnitName gives only the first).
    local MSC = _G.MSC
    local name = (MSC and MSC.GetCharacterName and MSC.GetCharacterName()) or UnitName("player")
    local key = name .. " - " .. GetRealmName()
    local legacy = UnitName("player") .. " - " .. GetRealmName()
    if not SGJ_LaboratoryDB[key] and legacy ~= key and SGJ_LaboratoryDB[legacy] then
        -- copy the sets saved under the old first-name key (several characters may share it)
        local copy = {}
        for k, v in pairs(SGJ_LaboratoryDB[legacy]) do copy[k] = v end
        SGJ_LaboratoryDB[key] = copy
    end
    if not SGJ_LaboratoryDB[key] then SGJ_LaboratoryDB[key] = {} end
    return SGJ_LaboratoryDB[key]
end

function SGF.SaveCurrentSet()
    local MSC = _G.MSC
    local name = MSC.ViewLaboratory.NameInput:GetText()
    local setIdx = SGF.ActiveSet
    
    if not name or name == "" then 
        print(string.format(L["|cffff0000SGJ:|r Please enter a name for Set %d"], setIdx))
        return 
    end
    
    local charDB = SGF.GetCharDB()
    charDB[name] = {}
    for k, v in pairs(SGF.LabItems[setIdx]) do charDB[name][k] = v end
    
    print(string.format(L["|cff00ff00SGJ:|r Saved Active Set (%d) as '%s'"], setIdx, name))
    MSC.ViewLaboratory.NameInput:ClearFocus()
    UIDropDownMenu_SetText(MSC.ViewLaboratory.LoadDD, name)
end

function SGF.LoadSet(name)
    local charDB = SGF.GetCharDB()
    if not charDB or not charDB[name] then return end
    
    local setIdx = SGF.ActiveSet
    SGF.LabItems[setIdx] = {}
    for k, v in pairs(charDB[name]) do SGF.LabItems[setIdx][k] = v end
    
    local MSC = _G.MSC
    for _, s in ipairs(SGF.OrderedSlots) do SGF.UpdateLabSlot(s, setIdx) end
    SGF.CalculateLabScore()
    MSC.ViewLaboratory.NameInput:SetText(name)
    print(string.format(L["|cff00ccffSGJ:|r Loaded '%s' into Set %d"], name, setIdx))
end

function SGF.DeleteSelectedSet()
    local MSC = _G.MSC
    local name = UIDropDownMenu_GetText(MSC.ViewLaboratory.LoadDD)
    local charDB = SGF.GetCharDB()
    if name and charDB and charDB[name] then
        charDB[name] = nil
        print(string.format(L["|cffff0000SGJ:|r Deleted set '%s'."], name))
        SGF.ClearLab(nil)
    else
        print(L["|cffff0000SGJ:|r Select a set to delete first."])
    end
end

function SGF.SerializeSet()
    local parts = {}
    table.insert(parts, "SGJ:1") 
    local setIdx = SGF.ActiveSet
    for slotName, link in pairs(SGF.LabItems[setIdx]) do
        local rawString = link:match("(item:[%d:-]+)")
        if rawString then table.insert(parts, slotName .. "=" .. rawString) end
    end
    return table.concat(parts, "&")
end

function SGF.DeserializeSet(importStr)
    if type(importStr) ~= "string" or importStr == "" then return end
    
    local setIdx = SGF.ActiveSet
    SGF.LabItems[setIdx] = {} 

    -- [[ MODE 1: NATIVE SGJ ]]
    if importStr:find("^SGJ:1") then
        for chunk in importStr:gmatch("[^&]+") do
            if chunk ~= "SGJ:1" then
                local slotName, itemString = chunk:match("^([^=]+)=(.+)$")
                if slotName and itemString and SGF.SlotTextures[slotName] then
                    SGF.LabItems[setIdx][slotName] = itemString
                    SGF.UpdateLabSlot(slotName, setIdx)
                    GetItemInfo(itemString)
                end
            end
        end
        SGF.CalculateLabScore()
        print(string.format(L["|cff00ff00SGJ:|r Native Set Imported into Set %d"], setIdx))
        return
    end

    -- [[ MODE 2: JSON (SeventyUpgrades) ]]
    if importStr:find("\"items\":") or importStr:find("\"gameClass\":") then
        print(L["|cff00ccffSGJ:|r JSON detected. Parsing structure..."])
        local jsonMap = {
            ["HEAD"] = "HeadSlot", ["NECK"] = "NeckSlot", ["SHOULDERS"] = "ShoulderSlot", 
            ["BACK"] = "BackSlot", ["CHEST"] = "ChestSlot", ["WRISTS"] = "WristSlot", 
            ["HANDS"] = "HandsSlot", ["WAIST"] = "WaistSlot", ["LEGS"] = "LegsSlot", 
            ["FEET"] = "FeetSlot", ["FINGER_1"] = "Finger0Slot", ["FINGER_2"] = "Finger1Slot", 
            ["TRINKET_1"] = "Trinket0Slot", ["TRINKET_2"] = "Trinket1Slot", 
            ["MAIN_HAND"] = "MainHandSlot", ["OFF_HAND"] = "SecondaryHandSlot", ["RANGED"] = "RangedSlot"
        }
        
        local itemsBlock = importStr:match('"items":%s*(%b[])')
        if itemsBlock then
            for itemObj in itemsBlock:gmatch("(%b{})") do
                local slotKey = itemObj:match('"slot":%s*"([^"]+)"')
                local targetSlot = jsonMap[slotKey]
                if targetSlot then
                    local itemID = itemObj:match('"id":%s*(%d+)')
                    if itemID then
                        local enchantID = 0
                        local enchantBlock = itemObj:match('"enchant":%s*(%b{})')
                        if enchantBlock then enchantID = enchantBlock:match('"id":%s*(%d+)') or 0 end
                        SGF.LabItems[setIdx][targetSlot] = "item:"..itemID..":"..enchantID..":0:0:0:0:0:0"
                        SGF.UpdateLabSlot(targetSlot, setIdx)
                        C_Item.RequestLoadItemDataByID(tonumber(itemID))
                    end
                end
            end
        end
        SGF.CalculateLabScore()
        print(L["|cff00ff00SGJ:|r JSON Import Complete."])
        return
    end

    -- [[ MODE 3: SIMC / RAIDBOTS ]]
    -- Format: "head=item_name,id=1234,enchant_id=56"
    if importStr:find("id=") then
        print(L["|cff00ccffSGJ:|r SimC format detected..."])
        -- Map SimC slot names to ours
        local simcMap = {
            ["head"] = "HeadSlot", ["neck"] = "NeckSlot", ["shoulders"] = "ShoulderSlot", 
            ["back"] = "BackSlot", ["chest"] = "ChestSlot", ["wrists"] = "WristSlot", 
            ["hands"] = "HandsSlot", ["waist"] = "WaistSlot", ["legs"] = "LegsSlot", 
            ["feet"] = "FeetSlot", ["finger1"] = "Finger0Slot", ["finger2"] = "Finger1Slot", 
            ["trinket1"] = "Trinket0Slot", ["trinket2"] = "Trinket1Slot", 
            ["main_hand"] = "MainHandSlot", ["off_hand"] = "SecondaryHandSlot", ["ranged"] = "RangedSlot"
        }

        for line in importStr:gmatch("[^\r\n]+") do
            local slotKey, params = line:match("^([%w_]+)=(.+)$")
            if slotKey and simcMap[slotKey] then
                local targetSlot = simcMap[slotKey]
                local itemID = params:match("id=(%d+)")
                local enchantID = params:match("enchant_id=(%d+)") or 0
                
                if itemID then
                    SGF.LabItems[setIdx][targetSlot] = "item:"..itemID..":"..enchantID..":0:0:0:0:0:0"
                    SGF.UpdateLabSlot(targetSlot, setIdx)
                    C_Item.RequestLoadItemDataByID(tonumber(itemID))
                end
            end
        end
        SGF.CalculateLabScore()
        print(L["|cff00ff00SGJ:|r SimC Import Complete."])
        return
    end

    -- [[ MODE 4: GENERIC SCRAPER (Wowhead "Links" / Text Lists) ]]
    print(L["|cff00ccffSGJ:|r Parsing generic item list..."])
    for id in importStr:gmatch("%d+") do
        local itemID = tonumber(id)
        if itemID and itemID > 2000 then 
            local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
            if equipLoc and equipLoc ~= "" then
                local slotName = SGF.GetSlotFromLoc(equipLoc, SGF.LabItems[setIdx])
                if slotName then
                    SGF.LabItems[setIdx][slotName] = "item:"..itemID..":0:0:0:0:0:0:0"
                    SGF.UpdateLabSlot(slotName, setIdx)
                end
            else
                C_Item.RequestLoadItemDataByID(itemID) 
            end
        end
    end
    SGF.CalculateLabScore()
    print(L["|cff00ff00SGJ:|r List Parsed."])
end

function SGF.CreateCopyPastePopup()
    if SGF.Popup then return SGF.Popup end
    
    -- Added BackdropTemplate to support standard UI borders
    local f = CreateFrame("Frame", "SGJ_CopyPastePopup", UIParent, "BackdropTemplate")
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    
    -- Replace the plain black texture with the classic DialogBox style used in your Help menu
    f:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
        tile=true, tileSize=32, edgeSize=32, 
        insets={left=11, right=12, top=12, bottom=11}
    })

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Title:SetPoint("TOP", 0, -20) -- Adjusted slightly down for the new border
    f.Title:SetText(L["Export / Import"])
    
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)
    
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 25, -50)
    scroll:SetPoint("BOTTOMRIGHT", -40, 50)
    
    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetSize(330, 400)
    eb:SetMultiLine(true)
    eb:SetFontObject("GameFontHighlight")
    eb:SetAutoFocus(false)
    scroll:SetScrollChild(eb)
    f.EditBox = eb

    -- QUALITY OF LIFE: Allow pressing Escape to clear focus and close the popup
    eb:SetScript("OnEscapePressed", function(self) 
        self:ClearFocus()
        f:Hide() 
    end)

    -- BUG FIX: Clicking anywhere on the main window will refocus the text box
    f:SetScript("OnMouseDown", function() 
        eb:SetFocus() 
    end)

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(100, 25)
    btn:SetPoint("BOTTOM", 0, 20)
    btn:SetText(L["Import This"])
    btn:SetScript("OnClick", function() 
        local text = eb:GetText()
        SGF.DeserializeSet(text)
        f:Hide() 
    end)
    f.ImportBtn = btn
    
    f.Hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Hint:SetPoint("BOTTOM", 0, 50)
    f.Hint:SetText(L["Press Ctrl+C to Copy or Ctrl+V to Paste"])
    f.Hint:SetTextColor(0.6, 0.6, 0.6)
    
    f:Hide()
    SGF.Popup = f
    return f
end

-- [[ 4.5 BEST IN BAG SCANNER ]]
local BIB_FINGER = { "Finger0Slot", "Finger1Slot" }
local BIB_TRINKET = { "Trinket0Slot", "Trinket1Slot" }
local BIB_ONEHAND = { "MainHandSlot", "SecondaryHandSlot" }
local BIB_OFFHAND = { "SecondaryHandSlot" }
local BIB_MAINHAND = { "MainHandSlot" }
local BIB_NONE = {}
-- Partner slots: the same item twice is only blocked when it is unique
local BIB_PARTNER = {
    Finger0Slot = "Finger1Slot", Finger1Slot = "Finger0Slot",
    Trinket0Slot = "Trinket1Slot", Trinket1Slot = "Trinket0Slot",
    MainHandSlot = "SecondaryHandSlot", SecondaryHandSlot = "MainHandSlot",
}

-- "Unique" / "Unique-Equipped" read from the item tooltip, cached by item ID
local uniqueCache = {}
local function IsUniqueItem(link)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return false end
    if uniqueCache[id] ~= nil then return uniqueCache[id] end
    local tip = _G["SGF_UniqueScanTooltip"] or CreateFrame("GameTooltip", "SGF_UniqueScanTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE"); tip:ClearLines()
    if not pcall(tip.SetHyperlink, tip, link) then return false end
    local unique = false
    local u1, u2 = ITEM_UNIQUE or "Unique", ITEM_UNIQUE_EQUIPPABLE or "Unique-Equipped"
    for i = 2, math.min(tip:NumLines(), 6) do
        local text = _G["SGF_UniqueScanTooltipTextLeft" .. i] and _G["SGF_UniqueScanTooltipTextLeft" .. i]:GetText()
        if text and (text == u1 or text == u2 or string.find(text, u1, 1, true) == 1) then unique = true; break end
    end
    if tip:NumLines() > 1 then uniqueCache[id] = unique end
    return unique
end

-- Is the bag item already bound to you? Unbound gear (Bind on Equip) asks
-- for a confirmation before it equips, which a script can't answer.
local function IsBagItemBound(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if type(info) == "table" and info.isBound ~= nil then return info.isBound and true or false end
    end
    if C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, bound = pcall(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(bag, slot))
        if ok and bound ~= nil then return bound and true or false end
    end
    local tip = _G["SGF_UniqueScanTooltip"] or CreateFrame("GameTooltip", "SGF_UniqueScanTooltip", nil, "GameTooltipTemplate")
    tip:SetOwner(WorldFrame, "ANCHOR_NONE"); tip:ClearLines()
    if not tip.SetBagItem or not pcall(tip.SetBagItem, tip, bag, slot) then return false end
    for i = 2, math.min(tip:NumLines(), 6) do
        local fs = _G["SGF_UniqueScanTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text then
            for _, m in ipairs({ "ITEM_SOULBOUND", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND" }) do
                if _G[m] and text == _G[m] then return true end
            end
        end
    end
    return false
end

function SGF.ScanBestInBags(autoEquip)
    local MSC = _G.MSC
    if not MSC or not MSC.GetTotalCharacterScore then return end

    local setIdx = SGF.ActiveSet
    -- The set's own profile; equipping for real always scores at your own level
    local weights, profileName = SGF.ResolveWeights(setIdx, (not autoEquip) and SGF.GetLookLevel() or UnitLevel("player"))

    if not weights then print(L["|cffff0000SGJ:|r No active stat weights found."]); return end

    local slotMap = { 
        HeadSlot=1, NeckSlot=2, ShoulderSlot=3, BackSlot=15, ChestSlot=5, 
        WristSlot=9, HandsSlot=10, WaistSlot=6, LegsSlot=7, FeetSlot=8, 
        Finger0Slot=11, Finger1Slot=12, Trinket0Slot=13, Trinket1Slot=14, 
        MainHandSlot=16, SecondaryHandSlot=17, RangedSlot=18 
    }
    
    local bagItems = {}
    local getLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
    local getSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    -- Equipping needs your real level; the Lab's look-ahead level otherwise
    local levelLimit = autoEquip and (UnitLevel("player") or 1) or SGF.GetLookLevel()
    for bag = 0, 4 do
        for slot = 1, getSlots(bag) do
            local link = getLink(bag, slot)
            if link then
                local _, _, _, _, reqLevel, _, _, _, equipLoc = GetItemInfo(link)
                -- Gear the character can't wear (or can't wear yet) would only fail to equip
                if equipLoc and equipLoc ~= "" and (reqLevel or 0) <= levelLimit
                    and (not MSC.IsItemUsable or MSC.IsItemUsable(link)) then
                    table.insert(bagItems, {link=link, loc=equipLoc, id=tonumber(link:match("item:(%d+)")), bag=bag, slot=slot})
                end
            end
        end
    end

    if #bagItems == 0 then print(L["|cff00ccffSGJ:|r No gear found in bags."]); return end
    print(L["|cff00ccffSGJ:|r Scanning bags for upgrades..."])

    local maxIterations = 20
    local itemsSwapped = 0
    local itemsToEquip = {}
    -- One bag item can fill one slot: usedBy[slotName] = the bag item placed there
    local usedBy = {}
    local function FreeSlot(sName)
        if usedBy[sName] then usedBy[sName].used = nil; usedBy[sName] = nil end
    end
    -- Scored trial gear; GetTotalCharacterScore keeps no reference to it, so one table is reused
    local testSimGear = {}

    for _ = 1, maxIterations do
        local bestItem, bestSlot = nil, nil
        local bestDelta = 0.1

        local currentSimGear = {}
        
        -- OPTION B LOGIC: Shift-Click looks at REAL gear, Normal looks at LAB gear.
        if autoEquip then
            for sName, slotNum in pairs(slotMap) do
                local slotID = GetInventorySlotInfo(sName)
                local link = GetInventoryItemLink("player", slotID)
                
                -- If we found an upgrade in a previous loop iteration, use that
                if itemsToEquip[sName] then
                    currentSimGear[slotNum] = itemsToEquip[sName]
                elseif link then
                    currentSimGear[slotNum] = link
                end
            end
        else
            for sName, l in pairs(SGF.LabItems[setIdx]) do
                if l and slotMap[sName] then currentSimGear[slotMap[sName]] = l end
            end
        end

        local baseScore = MSC:GetTotalCharacterScore(currentSimGear, weights, profileName)

        for _, bItem in ipairs(bagItems) do
          if not bItem.used then
            local potentialSlots
            local loc = bItem.loc

            if loc == "INVTYPE_FINGER" then potentialSlots = BIB_FINGER
            elseif loc == "INVTYPE_TRINKET" then potentialSlots = BIB_TRINKET
            elseif loc == "INVTYPE_WEAPON" then potentialSlots = BIB_ONEHAND
            elseif loc == "INVTYPE_SHIELD" or loc == "INVTYPE_HOLDABLE" or loc == "INVTYPE_WEAPONOFFHAND" then potentialSlots = BIB_OFFHAND
            elseif loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_WEAPONMAINHAND" then potentialSlots = BIB_MAINHAND
            else
                local s = SGF.GetSlotFromLoc(loc, currentSimGear)
                potentialSlots = s and { s } or BIB_NONE
            end

            for _, pSlot in ipairs(potentialSlots) do
                local itemID = bItem.id

                -- A second copy (rings, trinkets, one-handers) is fine unless the item is unique
                local partnerSlotNum = BIB_PARTNER[pSlot] and slotMap[BIB_PARTNER[pSlot]]
                local partnerLink = partnerSlotNum and currentSimGear[partnerSlotNum]
                local partnerID = partnerLink and tonumber(partnerLink:match("item:(%d+)"))

                if not (partnerID and partnerID == itemID and IsUniqueItem(bItem.link)) then
                    wipe(testSimGear)
                    for k, v in pairs(currentSimGear) do testSimGear[k] = v end
                    testSimGear[slotMap[pSlot]] = bItem.link

                    if pSlot == "MainHandSlot" and loc == "INVTYPE_2HWEAPON" then
                        testSimGear[slotMap["SecondaryHandSlot"]] = nil
                    elseif pSlot == "SecondaryHandSlot" then
                        local mhLink = currentSimGear[slotMap["MainHandSlot"]]
                        if mhLink then
                            local _,_,_,_,_,_,_,_,mhLoc = GetItemInfo(mhLink)
                            if mhLoc == "INVTYPE_2HWEAPON" then testSimGear[slotMap["MainHandSlot"]] = nil end
                        end
                    end

                    local testScore = MSC:GetTotalCharacterScore(testSimGear, weights, profileName)
                    local delta = testScore - baseScore
                    
                    if delta > bestDelta then
                        bestDelta = delta
                        bestItem = bItem
                        bestSlot = pSlot
                    end
                end
            end
          end
        end

        if bestItem and bestSlot then
            itemsSwapped = itemsSwapped + 1
            itemsToEquip[bestSlot] = bestItem.link
            FreeSlot(bestSlot)
            usedBy[bestSlot] = bestItem
            bestItem.used = true
            -- A two-hander empties the off hand; an off-hand item empties a two-handed main hand
            if bestSlot == "MainHandSlot" and bestItem.loc == "INVTYPE_2HWEAPON" then
                FreeSlot("SecondaryHandSlot")
            elseif bestSlot == "SecondaryHandSlot" and usedBy["MainHandSlot"] and usedBy["MainHandSlot"].loc == "INVTYPE_2HWEAPON" then
                FreeSlot("MainHandSlot")
            end
            
            -- If NOT auto-equipping, apply directly to Lab UI during loop
            if not autoEquip then
                SGF.LabItems[setIdx][bestSlot] = bestItem.link
                SGF.UpdateLabSlot(bestSlot, setIdx)
                
                if bestSlot == "MainHandSlot" and bestItem.loc == "INVTYPE_2HWEAPON" then
                    SGF.LabItems[setIdx]["SecondaryHandSlot"] = nil
                    SGF.UpdateLabSlot("SecondaryHandSlot", setIdx)
                elseif bestSlot == "SecondaryHandSlot" then
                    local mhLink = SGF.LabItems[setIdx]["MainHandSlot"]
                    if mhLink then
                        local _,_,_,_,_,_,_,_,mhLoc = GetItemInfo(mhLink)
                        if mhLoc == "INVTYPE_2HWEAPON" then
                            SGF.LabItems[setIdx]["MainHandSlot"] = nil
                            SGF.UpdateLabSlot("MainHandSlot", setIdx)
                        end
                    end
                end
            else
                -- If auto-equipping, handle 2H logic for the equip queue
                if bestSlot == "MainHandSlot" and bestItem.loc == "INVTYPE_2HWEAPON" then
                    itemsToEquip["SecondaryHandSlot"] = nil
                elseif bestSlot == "SecondaryHandSlot" then
                    local mhLink = itemsToEquip["MainHandSlot"] or GetInventoryItemLink("player", GetInventorySlotInfo("MainHandSlot"))
                    if mhLink then
                        local _,_,_,_,_,_,_,_,mhLoc = GetItemInfo(mhLink)
                        if mhLoc == "INVTYPE_2HWEAPON" then itemsToEquip["MainHandSlot"] = nil end
                    end
                end
            end
        else
            break 
        end
    end

    -- Final Execution Phase
    if itemsSwapped > 0 then
        if autoEquip then
            if InCombatLockdown() then
                print(L["|cffff0000SGJ:|r Cannot equip items while in combat."])
            else
                -- Unbound gear (Bind on Equip) opens a "will bind to you" confirmation;
                -- equipping the next item would cancel it. Those are listed for you to
                -- equip yourself; bound gear is equipped straight away.
                local toEquip, toConfirm = {}, {}
                for slotName, link in pairs(itemsToEquip) do
                    local src = usedBy[slotName]
                    if src and src.bag and not IsBagItemBound(src.bag, src.slot) then
                        table.insert(toConfirm, link)
                    else
                        toEquip[slotName] = link
                    end
                end
                local nEquip = 0
                for _ in pairs(toEquip) do nEquip = nEquip + 1 end

                if nEquip > 0 then
                    print(string.format(L["|cff00ff00SGJ:|r Equipping %d upgrades from bags..."], nEquip))
                end
                -- Equip from the exact bag slot: by name, two copies of one weapon
                -- could both resolve to the same bag item
                local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
                for slotName, link in pairs(toEquip) do
                    local slotID = GetInventorySlotInfo(slotName)
                    local src = usedBy[slotName]
                    if src and src.bag and pickup and EquipCursorItem then
                        ClearCursor()
                        pickup(src.bag, src.slot)
                        EquipCursorItem(slotID)
                    else
                        EquipItemByName(link, slotID)
                    end
                end
                if #toConfirm > 0 then
                    print(string.format(L["|cffffd100SGJ:|r %d upgrades will bind to you when equipped. Equip them yourself:"], #toConfirm))
                    for _, link in ipairs(toConfirm) do print("   " .. link) end
                end

                if nEquip > 0 then
                    C_Timer.After(0.5, function()
                        SGF.ImportEquipped()
                        print(L["|cff00ff00SGJ:|r Active Lab Set updated to match your newly equipped gear."])
                    end)
                end
            end
        else
            print(string.format(L["|cff00ff00SGJ:|r Best in Bag applied! Found %d upgrades for Set %d."], itemsSwapped, setIdx))
            SGF.CalculateLabScore()
        end
    else
        print(L["|cff00ccffSGJ:|r No upgrades found in bags."])
    end
end

-- Fills a set from a slot ID -> link table, keeping the two-hand rule
local function FillSetFromSlots(setIdx, bySlotID)
    SGF.LabItems[setIdx] = {}
    for sName, id in pairs(SGF.SlotIDs) do
        local link = bySlotID[id]
        if link then SGF.LabItems[setIdx][sName] = link; GetItemInfo(link) end
    end
    local mh = SGF.LabItems[setIdx].MainHandSlot
    if mh and select(9, GetItemInfo(mh)) == "INVTYPE_2HWEAPON" then SGF.LabItems[setIdx].SecondaryHandSlot = nil end
    for _, s in ipairs(SGF.OrderedSlots) do SGF.UpdateLabSlot(s, setIdx) end
    SGF.CalculateLabScore()
end

-- [[ 4.6 ROADMAP GOAL SET ]]
-- Your gear with the Roadmap's picks swapped in: the whole chained set in
-- Chain Mode, otherwise the picks for the dungeon selected in the Roadmap.
function SGF.LoadRoadmapPicks()
    local MSC = _G.MSC
    local R = MSC and MSC.Roadmap
    if not R then print(L["|cffff0000SGJ:|r The Roadmap plugin isn't loaded."]); return end
    local setIdx = SGF.ActiveSet
    local gear = EquippedGear()
    local swapped = 0

    if R.ChainMode and R.VirtualGear and next(R.VirtualGear) then
        -- Only the Lab's own slots (no shirt or tabard)
        for _, id in pairs(SGF.SlotIDs) do
            if R.VirtualGear[id] ~= gear[id] then swapped = swapped + 1 end
            gear[id] = R.VirtualGear[id]
        end
    else
        if not R.ScanResults or not next(R.ScanResults) then
            print(L["|cffff0000SGJ:|r Pick a dungeon in the Roadmap first (or build a set with its Chain Mode)."])
            return
        end
        for id, list in pairs(R.ScanResults) do
            local i = (R.BestIndices and R.BestIndices[id]) or 1
            local pick = i ~= -1 and list[i]
            if pick and pick.gain and pick.gain > 0 then gear[id] = pick.link; swapped = swapped + 1 end
        end
        -- A dual-wield pick shows its partner weapon (ForcedPairs); a two-hander empties the off hand
        if R.ForcedPairs then
            for id, link in pairs(R.ForcedPairs) do gear[id] = link end
        end
    end

    FillSetFromSlots(setIdx, gear)
    print(string.format(L["|cff00ff00SGJ:|r Roadmap picks loaded into Set %d (%d slots changed)."], setIdx, swapped))
end

-- [[ 4.7 INSPECT TO LAB ]]
local inspectFrame = CreateFrame("Frame")
SGF.PendingInspect = nil

local function FinishInspect(tries)
    local p = SGF.PendingInspect
    if not p then return end
    local unit = (UnitGUID("target") == p.guid) and "target" or nil
    if not unit then
        SGF.PendingInspect = nil
        print(L["|cffff0000SGJ:|r Lost your target before their gear arrived."])
        return
    end
    -- Links can arrive a moment after the item IDs; wait for them a few times
    local gear, missing = {}, false
    for _, id in pairs(SGF.SlotIDs) do
        local link = GetInventoryItemLink(unit, id)
        if link then gear[id] = link
        elseif GetInventoryItemID and GetInventoryItemID(unit, id) then missing = true end
    end
    if missing and tries < 5 then
        C_Timer.After(0.3, function() FinishInspect(tries + 1) end)
        return
    end

    SGF.PendingInspect = nil
    inspectFrame:UnregisterEvent("INSPECT_READY")
    FillSetFromSlots(p.set, gear)
    if ClearInspectPlayer and not (InspectFrame and InspectFrame:IsShown()) then ClearInspectPlayer() end

    print(string.format(L["|cff00ff00SGJ:|r %s's gear loaded into Set %d."], p.name, p.set))
    local _, myClass = UnitClass("player")
    if p.class ~= myClass then
        print(L["|cffffd100SGJ:|r Different class: their gear is scored with your profile."])
    end
end

inspectFrame:SetScript("OnEvent", function(_, event, guid)
    if event == "INSPECT_READY" and SGF.PendingInspect and guid == SGF.PendingInspect.guid then
        FinishInspect(0)
    end
end)

function SGF.InspectTarget()
    if not UnitExists("target") or not UnitIsPlayer("target") then
        print(L["|cffff0000SGJ:|r Target a player to inspect first."])
        return
    end
    if UnitIsUnit("target", "player") then SGF.ImportEquipped(); return end
    if not NotifyInspect or (CanInspect and not CanInspect("target")) then
        print(L["|cffff0000SGJ:|r Can't inspect that player (too far away?)."])
        return
    end

    local guid = UnitGUID("target")
    local _, class = UnitClass("target")
    SGF.PendingInspect = { guid = guid, set = SGF.ActiveSet, name = UnitName("target"), class = class }
    inspectFrame:RegisterEvent("INSPECT_READY")
    NotifyInspect("target")
    C_Timer.After(4, function()
        if SGF.PendingInspect and SGF.PendingInspect.guid == guid then
            SGF.PendingInspect = nil
            inspectFrame:UnregisterEvent("INSPECT_READY")
            print(L["|cffff0000SGJ:|r Inspect timed out. Move closer and try again."])
        end
    end)
end

-- [[ 4.8 IN-GAME HELP MENU ]]
function SGF.ToggleHelp()
    if not SGF.HelpFrame then
        local f = CreateFrame("Frame", "SGJ_LabHelpFrame", UIParent, "BackdropTemplate")
        f:SetSize(480, 560)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        
        -- Classic WoW Popup Styling
        f:SetBackdrop({
            bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", 
            edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", 
            tile=true, tileSize=32, edgeSize=32, 
            insets={left=11, right=12, top=12, bottom=11}
        })
        f:EnableMouse(true)
        
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -20)
        title:SetText(L["The Laboratory - How to Use"])
        
        -- The text scrolls, so longer translations aren't cut off
        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 25, -55)
        scroll:SetPoint("BOTTOMRIGHT", -45, 55)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(410, 10)
        scroll:SetScrollChild(content)
        local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 0, 0)
        text:SetWidth(405)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        
        local instructions = 
            L["|cff00ccffThe Laboratory|r allows you to build and compare two full gear sets side-by-side to see exactly how stat changes affect your score."] .. "\n\n" ..
            L["|cffffff00Adding Items to a Set:|r"] .. "\n" ..
            L["  • |cff00ff00Shift-Click|r: Click any item in your bags, chat, or AtlasLoot to add it to the active set."] .. "\n" ..
            L["  • |cff00ff00Equipped|r: Pulls all gear currently worn by your character into the active set."] .. "\n" ..
            L["  • |cff00ff00Best in Bag|r: Scans your bags to build the highest-scoring set possible. |cffaaaaaa(Shift-Click this to physically evaluate and equip your character's best gear!)|r"] .. "\n" ..
			L["  • |cff00ff00Import Str|r: Paste data directly from SeventyUpgrades (JSON) or SimC/Raidbots."] .. "\n" ..
            L["  • |cff00ff00Roadmap Picks|r: Your gear with the Roadmap's recommended upgrades swapped in."] .. "\n" ..
            L["  • |cff00ff00Inspect Target|r: Loads the gear of the player you have targeted."] .. "\n\n" ..
            L["|cffffff00Comparing Sets:|r"] .. "\n" ..
            L["Toggle between |cff00ff00Set 1|r and |cff00ff00Set 2|r using the buttons above the paper dolls. The scrollable stat panel on the right will display a color-coded breakdown of the stat differences between the two sets."] .. "\n" ..
            L["Each set has its own profile, so the same gear can be scored for another spec or Talents build. The small number on each item is its own score."] .. "\n" ..
            L["Under each score: hit or defense against its target, and missing enchants."] .. "\n\n" ..
            L["|cffffff00What If:|r"] .. "\n" ..
            L["The level slider scores both sets at another level. Items you can't wear yet at that level are tinted red. |cff00ff00As Linked|r scores each item's own enchant; |cff00ff00Best Enchants|r fills every slot with the best one for your level."] .. "\n\n" ..
            L["|cffffff00Saving & Loading:|r"] .. "\n" ..
            L["Type a name into the text box and click |cff00ff00Save|r to store your theorycrafted set locally. Use the dropdown to load it later."]
            
        text:SetText(instructions)
        content:SetHeight(math.ceil(text:GetStringHeight()) + 10)
        -- Font metrics can settle after the first frame; size again when shown
        f:SetScript("OnShow", function() content:SetHeight(math.ceil(text:GetStringHeight()) + 10) end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(100, 25)
        closeBtn:SetPoint("BOTTOM", 0, 20)
        closeBtn:SetText(L["Got it!"])
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        
        SGF.HelpFrame = f
    end
    
    if SGF.HelpFrame:IsShown() then
        SGF.HelpFrame:Hide()
    else
        SGF.HelpFrame:Show()
    end
end

-- [[ 5. UI CONSTRUCTION ]]
-- Layout: profile and actions (left) | the two sets side by side (centre) | stat comparison (right)
local LAB_LEFT_W, LAB_RIGHT_W = 190, 250

function SGF.InitLaboratoryView(parent)
    local MSC = _G.MSC
    local f = CreateFrame("Frame", nil, parent); f:SetAllPoints(); f:Hide()

    -- ==========================================
    -- COLUMNS
    -- ==========================================
    local LCol = CreateFrame("Frame", nil, f)
    LCol:SetPoint("TOPLEFT"); LCol:SetPoint("BOTTOMLEFT"); LCol:SetWidth(LAB_LEFT_W)
    local R = CreateFrame("Frame", nil, f)
    R:SetPoint("TOPRIGHT"); R:SetPoint("BOTTOMRIGHT"); R:SetWidth(LAB_RIGHT_W)
    local C = CreateFrame("Frame", nil, f)
    C:SetPoint("TOPLEFT", LCol, "TOPRIGHT"); C:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT")
    for _, col in ipairs({ LCol, R }) do
        local shade = col:CreateTexture(nil, "BACKGROUND"); shade:SetAllPoints(); shade:SetColorTexture(0, 0, 0, 0.25)
    end
    local function Divider(col, side)
        local t = col:CreateTexture(nil, "BORDER"); t:SetColorTexture(1, 1, 1, 0.08); t:SetWidth(1)
        t:SetPoint("TOP" .. side, 0, 0); t:SetPoint("BOTTOM" .. side, 0, 0)
    end
    Divider(LCol, "RIGHT"); Divider(R, "LEFT")

    local BTN_W = LAB_LEFT_W - 24
    local function Header(text, anchor, yOff)
        local h = LCol:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        if anchor then h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff) else h:SetPoint("TOPLEFT", 12, -12) end
        h:SetText(text)
        return h
    end
    local function Button(text, anchor, yOff, onClick)
        local b = CreateFrame("Button", nil, LCol, "UIPanelButtonTemplate")
        b:SetSize(BTN_W, 22); b:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff); b:SetText(text)
        if onClick then b:SetScript("OnClick", onClick) end
        return b
    end

    -- ==========================================
    -- LEFT: TITLE, PROFILE, ACTIONS, SAVED SETS
    -- ==========================================
    f.Title = Header(L["The Laboratory"])

    -- In-Game Help Button
    f.HelpBtn = CreateFrame("Button", nil, LCol, "UIPanelButtonTemplate")
    f.HelpBtn:SetSize(22, 22)
    f.HelpBtn:SetPoint("TOPRIGHT", -12, -8)
    f.HelpBtn:SetText("?")
    f.HelpBtn:SetScript("OnClick", function() SGF.ToggleHelp() end)
    f.HelpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Help & Instructions"])
        GameTooltip:Show()
    end)
    f.HelpBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- A profile per set: the same gear can be scored for another spec or Talents build
    f.ProfileDD = {}
    local profAnchor = f.Title
    for setIdx = 1, 2 do
        local lbl = LCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", profAnchor, "BOTTOMLEFT", setIdx == 1 and 0 or 18, setIdx == 1 and -12 or -4)
        lbl:SetText(string.format(L["Set %d Profile"], setIdx)); lbl:SetTextColor(0.6, 0.6, 0.6)
        local dd = CreateFrame("Frame", "SGJ_LaboratoryProfileDD" .. setIdx, LCol, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", -18, -2)
        UIDropDownMenu_SetWidth(dd, BTN_W - 16); UIDropDownMenu_SetText(dd, L["Follow Main Addon"])
        UIDropDownMenu_Initialize(dd, function(self, level)
            local function Add(text, sel, isTitle)
                local info = UIDropDownMenu_CreateInfo()
                info.text = text
                if isTitle then
                    info.isTitle = true; info.notCheckable = true
                else
                    info.func = function() SGF.SetProfiles[setIdx] = sel; SGF.CalculateLabScore() end
                    info.checked = (SGF.SetProfiles[setIdx] == sel)
                end
                UIDropDownMenu_AddButton(info, level)
            end
            Add(L["Follow Main Addon"], nil)
            for _, e in ipairs(SGF.ProfileChoices()) do Add(e.text, e.sel, e.title) end
        end)
        f.ProfileDD[setIdx] = dd
        profAnchor = dd
    end

    -- Add items to the active set
    local hAdd = Header(L["Add to Active Set"], f.ProfileDD[2], -8)
    hAdd:SetPoint("TOPLEFT", f.ProfileDD[2], "BOTTOMLEFT", 18, -8)
    f.ActiveLbl = LCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); f.ActiveLbl:SetPoint("TOPLEFT", hAdd, "BOTTOMLEFT", 0, -3)
    f.ActiveLbl:SetWidth(BTN_W); f.ActiveLbl:SetJustifyH("LEFT"); f.ActiveLbl:SetTextColor(0.6, 0.6, 0.6)
    f.ActiveLbl:SetText(L["Shift-click items in your bags or chat. Pick the set with its button above the gear."])
    f.ImportBtn = Button(L["Equipped"], f.ActiveLbl, -8, function() SGF.ImportEquipped() end)

    -- Best in Bag Button (Shift-Click enabled)
    f.BagBtn = Button(L["Best in Bag"], f.ImportBtn, -4)
    f.BagBtn:SetScript("OnClick", function()
        local autoEquip = IsShiftKeyDown()
        SGF.ScanBestInBags(autoEquip)
    end)
    f.BagBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Best in Bag"])
        GameTooltip:AddLine(L["Scans bags to populate the current Lab Set"], 1, 1, 1)
        GameTooltip:AddLine(L["with your highest-scoring available gear."], 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["<Shift-Click> to also auto-equip the items."], 0, 1, 0)
        GameTooltip:Show()
    end)
    f.BagBtn:SetScript("OnLeave", GameTooltip_Hide)

    f.ImpStrBtn = Button(L["Import String"], f.BagBtn, -4, function() local p = SGF.CreateCopyPastePopup(); p.EditBox:SetText(""); p.ImportBtn:Show(); p.Title:SetText(string.format(L["Paste to Set %d"], SGF.ActiveSet)); p.EditBox:SetFocus(); p:Show() end)

    f.RoadmapBtn = Button(L["Roadmap Picks"], f.ImpStrBtn, -4, function() SGF.LoadRoadmapPicks() end)
    f.RoadmapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Roadmap Picks"])
        GameTooltip:AddLine(L["Your gear with the Roadmap's recommended upgrades swapped in."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Uses the dungeon selected in the Roadmap, or the whole set built in its Chain Mode."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    f.RoadmapBtn:SetScript("OnLeave", GameTooltip_Hide)

    f.InspectBtn = Button(L["Inspect Target"], f.RoadmapBtn, -4, function() SGF.InspectTarget() end)
    f.InspectBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Inspect Target"])
        GameTooltip:AddLine(L["Loads the gear of the player you have targeted."], 1, 1, 1, true)
        GameTooltip:AddLine(L["Their gear is scored with your profile."], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    f.InspectBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- Manage both sets
    local hManage = Header(L["Manage"], f.InspectBtn, -14)
    f.CopyBtn = Button(L["Copy Set 1 to Set 2"], hManage, -6, function() SGF.CopySet1To2() end)
    f.ShareBtn = Button(L["Export Active Set"], f.CopyBtn, -4, function() local p = SGF.CreateCopyPastePopup(); local s = SGF.SerializeSet(); p.EditBox:SetText(s); p.EditBox:HighlightText(); p.ImportBtn:Hide(); p.Title:SetText(string.format(L["Export Set %d"], SGF.ActiveSet)); p:Show() end)
    f.ClearBtn = Button(L["Clear All"], f.ShareBtn, -4, function() SGF.ClearLab(nil) end)

    -- Saved sets
    local hSaved = Header(L["Saved Sets"], f.ClearBtn, -14)
    f.NameInput = CreateFrame("EditBox", nil, LCol, "InputBoxTemplate"); f.NameInput:SetSize(BTN_W - 60, 22); f.NameInput:SetPoint("TOPLEFT", hSaved, "BOTTOMLEFT", 5, -6); f.NameInput:SetAutoFocus(false); f.NameInput:SetText(L["My Set"])
    f.SaveBtn = CreateFrame("Button", nil, LCol, "UIPanelButtonTemplate"); f.SaveBtn:SetSize(52, 22); f.SaveBtn:SetPoint("LEFT", f.NameInput, "RIGHT", 4, 0); f.SaveBtn:SetText(L["Save"]); f.SaveBtn:SetScript("OnClick", function() SGF.SaveCurrentSet() end)

    f.LoadDD = CreateFrame("Frame", "SGJ_LaboratoryLoadDD", LCol, "UIDropDownMenuTemplate"); f.LoadDD:SetPoint("TOPLEFT", f.NameInput, "BOTTOMLEFT", -23, -4); UIDropDownMenu_SetWidth(f.LoadDD, BTN_W - 46); UIDropDownMenu_SetText(f.LoadDD, L["Load Set..."])
    UIDropDownMenu_Initialize(f.LoadDD, function(self, level) local charDB = SGF.GetCharDB(); if not charDB then return end for name, _ in pairs(charDB) do local info = UIDropDownMenu_CreateInfo(); info.text = name; info.func = function() SGF.LoadSet(name); UIDropDownMenu_SetText(f.LoadDD, name) end; UIDropDownMenu_AddButton(info, level) end end)

    f.DelBtn = CreateFrame("Button", nil, LCol); f.DelBtn:SetSize(20, 20); f.DelBtn:SetPoint("LEFT", f.LoadDD, "RIGHT", -12, 2); f.DelBtn.Icon = f.DelBtn:CreateTexture(nil, "ARTWORK"); f.DelBtn.Icon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up"); f.DelBtn.Icon:SetAllPoints(); f.DelBtn:SetScript("OnClick", function() SGF.DeleteSelectedSet() end)
    f.DelBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["Delete the selected saved set"]); GameTooltip:Show() end)
    f.DelBtn:SetScript("OnLeave", GameTooltip_Hide)

    -- ==========================================
    -- CENTRE: SET 1 AND SET 2 SIDE BY SIDE
    -- ==========================================
    local col2X = 85
    local dollCoords = {
        HeadSlot = {x=0, y=0}, NeckSlot = {x=0, y=-38}, ShoulderSlot = {x=0, y=-76}, BackSlot = {x=0, y=-114}, ChestSlot = {x=0, y=-152}, WristSlot = {x=0, y=-190},
        MainHandSlot = {x=0, y=-228}, SecondaryHandSlot = {x=0, y=-266}, RangedSlot = {x=0, y=-304},
        HandsSlot = {x=col2X, y=0}, WaistSlot = {x=col2X, y=-38}, LegsSlot = {x=col2X, y=-76}, FeetSlot = {x=col2X, y=-114}, Finger0Slot = {x=col2X, y=-152}, Finger1Slot = {x=col2X, y=-190}, Trinket0Slot = {x=col2X, y=-228}, Trinket1Slot = {x=col2X, y=-266},
    }
    local DOLL_W = col2X + 34
    local centerW = 830 - LAB_LEFT_W - LAB_RIGHT_W
    local gap = (centerW - 2 * DOLL_W) / 3
    local dollX = { gap, 2 * gap + DOLL_W }
    local DOLL_TOP = -56

    -- Each set sits in a panel; the active one is outlined in gold
    f.SetPanels = {}
    for setIdx = 1, 2 do
        local p = CreateFrame("Frame", nil, C)
        p:SetPoint("TOPLEFT", dollX[setIdx] - 10, -8); p:SetSize(DOLL_W + 20, 476)
        p.Fill = p:CreateTexture(nil, "BACKGROUND"); p.Fill:SetAllPoints(); p.Fill:SetColorTexture(1, 1, 1, 0.02)
        p.Edge = {}
        for i, pts in ipairs({ {"TOPLEFT","TOPRIGHT"}, {"BOTTOMLEFT","BOTTOMRIGHT"}, {"TOPLEFT","BOTTOMLEFT"}, {"TOPRIGHT","BOTTOMRIGHT"} }) do
            local e = p:CreateTexture(nil, "BORDER"); e:SetColorTexture(1, 0.82, 0, 0.7)
            e:SetPoint(pts[1]); e:SetPoint(pts[2])
            if i <= 2 then e:SetHeight(1) else e:SetWidth(1) end
            p.Edge[i] = e
        end
        f.SetPanels[setIdx] = p
    end

    f.Set1Btn = CreateFrame("Button", nil, C, "UIPanelButtonTemplate"); f.Set1Btn:SetSize(DOLL_W, 22); f.Set1Btn:SetPoint("TOPLEFT", dollX[1], -18); f.Set1Btn:SetText(L["Set 1"])
    f.Set2Btn = CreateFrame("Button", nil, C, "UIPanelButtonTemplate"); f.Set2Btn:SetSize(DOLL_W, 22); f.Set2Btn:SetPoint("TOPLEFT", dollX[2], -18); f.Set2Btn:SetText(L["Set 2"])

    local function UpdateActiveSetUI()
        if SGF.ActiveSet == 1 then f.Set1Btn:LockHighlight(); f.Set2Btn:UnlockHighlight(); f.Set1Btn.Text:SetTextColor(1,1,0); f.Set2Btn.Text:SetTextColor(1,1,1)
        else f.Set1Btn:UnlockHighlight(); f.Set2Btn:LockHighlight(); f.Set1Btn.Text:SetTextColor(1,1,1); f.Set2Btn.Text:SetTextColor(1,1,0) end
        for idx, p in ipairs(f.SetPanels) do
            for _, e in ipairs(p.Edge) do e:SetShown(idx == SGF.ActiveSet) end
        end
    end
    f.Set1Btn:SetScript("OnClick", function() SGF.ActiveSet = 1; UpdateActiveSetUI() end)
    f.Set2Btn:SetScript("OnClick", function() SGF.ActiveSet = 2; UpdateActiveSetUI() end)
    UpdateActiveSetUI()

    f.Slots = { [1]={}, [2]={} }
    for setIdx = 1, 2 do
        for slotName, coords in pairs(dollCoords) do
            local btn = CreateFrame("Button", nil, C)
            btn:SetSize(34, 34); btn:SetPoint("TOPLEFT", dollX[setIdx] + coords.x, DOLL_TOP + coords.y)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn.Icon = btn:CreateTexture(nil, "ARTWORK"); btn.Icon:SetAllPoints(); btn.Icon:SetTexture(SGF.SlotTextures[slotName])
            btn.Border = btn:CreateTexture(nil, "OVERLAY"); btn.Border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); btn.Border:SetBlendMode("ADD"); btn.Border:SetAlpha(0.4); btn.Border:SetAllPoints(); btn.Border:Hide()
            -- The item's own score with this set's profile
            btn.ScoreText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            btn.ScoreText:SetPoint("BOTTOMRIGHT", -1, 2)
            btn:SetScript("OnClick", function(self, button)
                local t,_,l = GetCursorInfo()
                if t=="item" then SGF.ActiveSet = setIdx; UpdateActiveSetUI(); SGF.ReceiveLink(l); ClearCursor()
                elseif button == "RightButton" or IsShiftKeyDown() then SGF.LabItems[setIdx][slotName] = nil; SGF.UpdateLabSlot(slotName, setIdx); SGF.CalculateLabScore() end
            end)
            btn:SetScript("OnEnter", function(s)
                if s.link then
                    GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(s.link)
                    if s.TooHigh then GameTooltip:AddLine(string.format(L["Needs level %d (scoring at %d)"], s.TooHigh, SGF.GetLookLevel()), 1, 0.3, 0.3) end
                    GameTooltip:Show()
                end
                btn.Border:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip_Hide(); btn.Border:Hide() end)
            f.Slots[setIdx][slotName] = btn
        end
    end

    -- Scores under each set, the difference centred under both
    local scoreY = DOLL_TOP - 304 - 34 - 18
    f.ScoreVal1 = C:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal1:SetPoint("TOP", C, "TOPLEFT", dollX[1] + DOLL_W / 2, scoreY); f.ScoreVal1:SetText("0"); f.ScoreVal1:SetTextColor(1,1,0)
    f.ScoreVal2 = C:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal2:SetPoint("TOP", C, "TOPLEFT", dollX[2] + DOLL_W / 2, scoreY); f.ScoreVal2:SetText("0"); f.ScoreVal2:SetTextColor(1,1,0)

    -- Under each score: up to two cap lines (hit, defense) and the enchant line
    f.SetInfo = {}
    for setIdx = 1, 2 do
        local info = { Cap = {} }
        local x = dollX[setIdx] + DOLL_W / 2
        for i = 1, 3 do
            local t = C:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("TOP", C, "TOPLEFT", x, scoreY - 28 - (i - 1) * 13)
            t:SetWidth(DOLL_W + 40); t:SetWordWrap(false)
            if i < 3 then info.Cap[i] = t else info.Ench = t end
        end
        f.SetInfo[setIdx] = info
    end

    f.DiffVal = C:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); f.DiffVal:SetPoint("TOP", C, "TOP", 0, scoreY - 82); f.DiffVal:SetWidth(centerW - 20); f.DiffVal:SetText(L["Ready"])

    -- What-if controls: scoring level and enchant view
    local maxLevel = SGF.MaxLevel()
    local slider = CreateFrame("Slider", "SGJ_LabLevelSlider", C, "OptionsSliderTemplate")
    slider:SetPoint("TOP", C, "TOP", -22, scoreY - 128); slider:SetWidth(200)
    slider:SetMinMaxValues(1, maxLevel); slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    _G[slider:GetName() .. "Low"]:SetText("1"); _G[slider:GetName() .. "High"]:SetText(tostring(maxLevel))
    f.LevelSlider = slider
    function SGF.UpdateLevelText()
        local me, lvl = UnitLevel("player") or 1, SGF.GetLookLevel()
        local text = _G[slider:GetName() .. "Text"]
        if lvl == me then text:SetText(string.format(L["Score at level %d"], lvl))
        else text:SetText(string.format(L["Score at level %d |cffaaaaaa(you: %d)|r"], lvl, me)) end
    end
    slider:SetScript("OnValueChanged", function(self, v)
        if SGF.SyncingSlider then return end
        v = math.floor(v + 0.5)
        SGF.LookLevel = (v ~= UnitLevel("player")) and v or nil
        SGF.UpdateLevelText()
        SGF.QueueRecalc()
    end)
    slider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Level Look-Ahead"])
        GameTooltip:AddLine(L["Scores both sets with the stat weights of another level. Items you can't wear yet at that level are tinted red."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    slider:SetScript("OnLeave", GameTooltip_Hide)

    f.LevelResetBtn = CreateFrame("Button", nil, C, "UIPanelButtonTemplate")
    f.LevelResetBtn:SetSize(44, 20); f.LevelResetBtn:SetPoint("LEFT", slider, "RIGHT", 10, 0); f.LevelResetBtn:SetText(L["Now"])
    f.LevelResetBtn:SetScript("OnClick", function() SGF.LookLevel = nil; SGF.SyncLevelSlider(); SGF.CalculateLabScore() end)
    f.LevelResetBtn:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L["Back to your own level"]); GameTooltip:Show() end)
    f.LevelResetBtn:SetScript("OnLeave", GameTooltip_Hide)

    function SGF.SyncLevelSlider()
        SGF.SyncingSlider = true
        slider:SetValue(SGF.GetLookLevel())
        SGF.SyncingSlider = nil
        SGF.UpdateLevelText()
    end
    SGF.SyncLevelSlider()

    -- Enchant view: each item's own enchant, or the best one for every slot
    f.EnchBtns = {}
    local function UpdateEnchantButtons()
        local best = (SGF.GetOptions().EnchantView == "best")
        for view, b in pairs(f.EnchBtns) do
            local on = (view == "best") == best
            if on then b:LockHighlight(); b.Text:SetTextColor(1, 1, 0) else b:UnlockHighlight(); b.Text:SetTextColor(1, 1, 1) end
        end
    end
    local function EnchButton(view, text, tip, xOff)
        local b = CreateFrame("Button", nil, C, "UIPanelButtonTemplate")
        b:SetSize(160, 22); b:SetPoint("TOP", C, "TOP", xOff, scoreY - 170); b:SetText(text)
        b:SetScript("OnClick", function() SGF.GetOptions().EnchantView = (view == "best") and "best" or nil; UpdateEnchantButtons(); SGF.CalculateLabScore() end)
        b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(text); GameTooltip:AddLine(tip, 1, 1, 1, true); GameTooltip:Show() end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        f.EnchBtns[view] = b
    end
    EnchButton("linked", L["As Linked"], L["Scores each item with the enchant it has (or none)."], -83)
    EnchButton("best", L["Best Enchants"], L["Scores every enchantable slot with the best enchant for your level."], 83)
    UpdateEnchantButtons()

    local slotHint = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotHint:SetPoint("BOTTOM", 0, 8); slotHint:SetText(L["Right-click or shift-click a slot to empty it"]); slotHint:SetTextColor(0.5, 0.5, 0.5)

    -- ==========================================
    -- RIGHT: STAT COMPARISON
    -- ==========================================
    local statHdr = R:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statHdr:SetPoint("TOPLEFT", 12, -12); statHdr:SetText(L["Stat Comparison"])

    -- Column headings line up with the row columns built in SGF.UpdateStatList
    local headRow = CreateFrame("Frame", nil, R)
    headRow:SetPoint("TOPLEFT", statHdr, "BOTTOMLEFT", 0, -8); headRow:SetPoint("RIGHT", R, "RIGHT", -34, 0); headRow:SetHeight(14)
    local function HeadCell(text, rightOff, width)
        local t = headRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t:SetText(text); t:SetTextColor(0.6, 0.6, 0.6)
        if rightOff then t:SetPoint("RIGHT", headRow, "RIGHT", rightOff, 0); t:SetWidth(width); t:SetJustifyH("RIGHT")
        else t:SetPoint("LEFT", headRow, "LEFT", 2, 0) end
    end
    HeadCell(L["Stat"]); HeadCell(L["Set 1"], SGF.STAT_COL_V1, SGF.STAT_COL_W); HeadCell(L["Set 2"], SGF.STAT_COL_V2, SGF.STAT_COL_W); HeadCell(L["Diff"], SGF.STAT_COL_DIFF, SGF.STAT_COL_W)

    local scroll = CreateFrame("ScrollFrame", nil, R, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", headRow, "BOTTOMLEFT", 0, -4); scroll:SetPoint("BOTTOMRIGHT", -34, 12)
    f.StatScroll = scroll
    f.StatScroll.Content = CreateFrame("Frame", nil, scroll)
    f.StatScroll.Content:SetSize(LAB_RIGHT_W - 46, 600)
    scroll:SetScrollChild(f.StatScroll.Content)
    f.StatEmpty = R:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.StatEmpty:SetPoint("TOPLEFT", scroll, "TOPLEFT", 2, -4); f.StatEmpty:SetWidth(LAB_RIGHT_W - 50); f.StatEmpty:SetJustifyH("LEFT")
    f.StatEmpty:SetText(L["Add items to either set to compare their stats."]); f.StatEmpty:SetTextColor(0.6, 0.6, 0.6)
    -- Rows anchor to both edges of the content, so keeping the content as wide as the scroll area keeps every row in step
    scroll:SetScript("OnSizeChanged", function(self, w) if w and w > 50 then f.StatScroll.Content:SetWidth(w) end end)

	MSC.ViewLaboratory = f
    f:SetScript("OnShow", function()
        SGF.itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        SGF.UpdateLaboratory()
    end)
    f:SetScript("OnHide", function() SGF.itemInfoFrame:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end)
end

-- Items the game hasn't sent yet (inspected or imported gear) score 0 at
-- first; while the Lab is open, rescore once their data arrives.
SGF.itemInfoFrame = CreateFrame("Frame")
SGF.itemInfoFrame:SetScript("OnEvent", function(_, _, itemID, success)
    itemID = tonumber(itemID)
    if not itemID or success == false then return end
    local hit = false
    for idx = 1, 2 do
        for sName, link in pairs(SGF.LabItems[idx]) do
            if link and tonumber(link:match("item:(%d+)")) == itemID then
                SGF.UpdateLabSlot(sName, idx)
                hit = true
            end
        end
    end
    if hit then SGF.QueueRecalc() end
end)

-- Each time the tab opens: you may have levelled or changed talents since
function SGF.UpdateLaboratory()
    if SGF.SyncLevelSlider then SGF.SyncLevelSlider() end
    SGF.CalculateLabScore()
end

-- [[ 6. HOOKS ]]
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", function()
    local MSC = _G.MSC 
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    if MSC and MSC.RegisterPluginTab then 
        MSC.RegisterPluginTab(L["The Lab"], "Interface\\Icons\\INV_Chest_Plate04", SGF.InitLaboratoryView, "ViewLaboratory", "UpdateLaboratory")
        if MSC.RenderSidebarButtons then MSC.RenderSidebarButtons() end
        
        local function LabOpen()
            return MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK")
        end
        -- One click can reach several of the hooks below (a bag click runs both
        -- the bag button's handler and HandleModifiedItemClick): take the item
        -- once per click. Keyed by the item string, since some hooks get the
        -- full link and others only "item:...".
        local lastKey, lastTime
        local function Take(link)
            if type(link) ~= "string" or not link:find("item:", 1, true) then return end
            local key, now = link:match("item:[%-%d:]+") or link, GetTime()
            if key == lastKey and now == lastTime then return end
            lastKey, lastTime = key, now
            SGF.ReceiveLink(link)
        end
        local function BagButtonLink(self)
            local b = self.GetBagID and self:GetBagID() or self:GetParent():GetID()
            local s = self:GetID()
            return (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(b,s) or GetContainerItemLink(b,s)
        end

        -- Bag addons (Baganator, Bagnon...) and most other item buttons go through this
        if type(HandleModifiedItemClick) == "function" then
            hooksecurefunc("HandleModifiedItemClick", function(link) if LabOpen() then Take(link) end end)
        end
        if type(SetItemRef) == "function" then
            hooksecurefunc("SetItemRef", function(link) if LabOpen() then Take(link) end end)
        end
        if type(ContainerFrameItemButton_OnModifiedClick) == "function" then
            hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self)
                if LabOpen() then Take(BagButtonLink(self)) end
            end)
        end
        if type(ContainerFrameItemButtonTemplate_OnModifiedClick) == "function" then
            hooksecurefunc("ContainerFrameItemButtonTemplate_OnModifiedClick", function(self)
                if LabOpen() then Take(BagButtonLink(self)) end
            end)
        end
        if type(PaperDollItemSlotButton_OnModifiedClick) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", function(self) if LabOpen() then Take(GetInventoryItemLink("player", self:GetID())) end end)
        end
    end
end)