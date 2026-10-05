local addonName, SGF = ... 
local L = (_G.MSC and _G.MSC.L) or setmetatable({}, { __index = function(t, k) return k end })
SGF.LabItems = { [1]={}, [2]={} }
SGF.ActiveSet = 1 -- Which set is currently receiving inputs?
SGF.StatRows = {} 
SGF.SelectedProfile = nil

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

function SGF.CalculateLabScore()
    local MSC = _G.MSC 
    if not MSC or not MSC.ViewLaboratory or not MSC.ViewLaboratory.ScoreVal1 then return end

    local weights, profileName
    if SGF.SelectedProfile and SGF.SelectedProfile ~= "Global" then
        profileName = SGF.SelectedProfile
        if MSC.CurrentClass and MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[profileName] then
            weights = MSC.CurrentClass.Weights[profileName]
        else
            weights, profileName = MSC.GetCurrentWeights()
        end
    else
        weights, profileName = MSC.GetCurrentWeights()
    end
    
    local dispName = (MSC.CurrentClass and MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[profileName]) or profileName
    UIDropDownMenu_SetText(MSC.ViewLaboratory.SpecDD, dispName)

    -- Define Slot Map
    local slotMap = { 
        HeadSlot=1, NeckSlot=2, ShoulderSlot=3, BackSlot=15, ChestSlot=5, 
        WristSlot=9, HandsSlot=10, WaistSlot=6, LegsSlot=7, FeetSlot=8, 
        Finger0Slot=11, Finger1Slot=12, Trinket0Slot=13, Trinket1Slot=14, 
        MainHandSlot=16, SecondaryHandSlot=17, RangedSlot=18 
    }

    -- Helper to calc score for a set index
    local function GetSetScore(idx)
        local gear = {}
        for sName, link in pairs(SGF.LabItems[idx]) do
            if link and slotMap[sName] then gear[slotMap[sName]] = link end
        end
        return MSC:GetTotalCharacterScore(gear, weights, profileName)
    end

    local s1, stats1 = GetSetScore(1)
    local s2, stats2 = GetSetScore(2)

    -- Update UI Scores
    MSC.ViewLaboratory.ScoreVal1:SetText(string.format("%.1f", s1))
    MSC.ViewLaboratory.ScoreVal2:SetText(string.format("%.1f", s2))
    
    local diff = s2 - s1
    if diff > 0.1 then
        MSC.ViewLaboratory.DiffVal:SetText(string.format(L["Set 2 is |cff00ff00+%.1f|r better"], diff))
    elseif diff < -0.1 then
        MSC.ViewLaboratory.DiffVal:SetText(string.format(L["Set 1 is |cff00ff00+%.1f|r better"], math.abs(diff)))
    else
        MSC.ViewLaboratory.DiffVal:SetText(L["|cff888888Sets are Equal|r"])
    end

    SGF.UpdateStatList(stats1, stats2, weights)
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
    local key = UnitName("player") .. " - " .. GetRealmName()
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

function SGF.ScanBestInBags(autoEquip)
    local MSC = _G.MSC
    if not MSC or not MSC.GetTotalCharacterScore then return end

    local setIdx = SGF.ActiveSet
    local weights, profileName
    if SGF.SelectedProfile and SGF.SelectedProfile ~= "Global" then
        profileName = SGF.SelectedProfile
        if MSC.CurrentClass and MSC.CurrentClass.Weights and MSC.CurrentClass.Weights[profileName] then
            weights = MSC.CurrentClass.Weights[profileName]
        else
            weights, profileName = MSC.GetCurrentWeights()
        end
    else
        weights, profileName = MSC.GetCurrentWeights()
    end

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
    for bag = 0, 4 do
        for slot = 1, getSlots(bag) do
            local link = getLink(bag, slot)
            if link then
                local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(link)
                -- Gear the character can't wear would only fail to equip
                if equipLoc and equipLoc ~= "" and (not MSC.IsItemUsable or MSC.IsItemUsable(link)) then
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
                print(string.format(L["|cff00ff00SGJ:|r Equipping %d upgrades from bags..."], itemsSwapped))
                -- Equip from the exact bag slot: by name, two copies of one weapon
                -- could both resolve to the same bag item
                local pickup = (C_Container and C_Container.PickupContainerItem) or PickupContainerItem
                for slotName, link in pairs(itemsToEquip) do
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
                
                C_Timer.After(0.5, function()
                    SGF.ImportEquipped()
                    print(L["|cff00ff00SGJ:|r Active Lab Set updated to match your newly equipped gear."])
                end)
            end
        else
            print(string.format(L["|cff00ff00SGJ:|r Best in Bag applied! Found %d upgrades for Set %d."], itemsSwapped, setIdx))
            SGF.CalculateLabScore()
        end
    else
        print(L["|cff00ccffSGJ:|r No upgrades found in bags."])
    end
end

-- [[ 4.8 IN-GAME HELP MENU ]]
function SGF.ToggleHelp()
    if not SGF.HelpFrame then
        local f = CreateFrame("Frame", "SGJ_LabHelpFrame", UIParent, "BackdropTemplate")
        f:SetSize(450, 420)
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
        
        local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 25, -55)
        text:SetPoint("BOTTOMRIGHT", -25, 50)
        text:SetJustifyH("LEFT")
        text:SetJustifyV("TOP")
        
        local instructions = 
            L["|cff00ccffThe Laboratory|r allows you to build and compare two full gear sets side-by-side to see exactly how stat changes affect your score."] .. "\n\n" ..
            L["|cffffff00Adding Items to a Set:|r"] .. "\n" ..
            L["  • |cff00ff00Shift-Click|r: Click any item in your bags, chat, or AtlasLoot to add it to the active set."] .. "\n" ..
            L["  • |cff00ff00Equipped|r: Pulls all gear currently worn by your character into the active set."] .. "\n" ..
            L["  • |cff00ff00Best in Bag|r: Scans your bags to build the highest-scoring set possible. |cffaaaaaa(Shift-Click this to physically evaluate and equip your character's best gear!)|r"] .. "\n" ..
			L["  • |cff00ff00Import Str|r: Paste data directly from SeventyUpgrades (JSON) or SimC/Raidbots."] .. "\n\n" ..
            L["|cffffff00Comparing Sets:|r"] .. "\n" ..
            L["Toggle between |cff00ff00Set 1|r and |cff00ff00Set 2|r using the buttons above the paper dolls. The scrollable stat panel on the right will display a color-coded breakdown of the stat differences between the two sets."] .. "\n\n" ..
            L["|cffffff00Saving & Loading:|r"] .. "\n" ..
            L["Type a name into the text box and click |cff00ff00Save|r to store your theorycrafted set locally. Use the dropdown to load it later."]
            
        text:SetText(instructions)
        
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

    local profLbl = LCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profLbl:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -12); profLbl:SetText(L["Scoring Profile"]); profLbl:SetTextColor(0.6, 0.6, 0.6)
    f.SpecDD = CreateFrame("Frame", "SGJ_LaboratorySpecDD", LCol, "UIDropDownMenuTemplate"); f.SpecDD:SetPoint("TOPLEFT", profLbl, "BOTTOMLEFT", -18, -2)
    UIDropDownMenu_SetWidth(f.SpecDD, BTN_W - 16); UIDropDownMenu_SetText(f.SpecDD, L["Follow Main Addon"])
	UIDropDownMenu_Initialize(f.SpecDD, function(self, level)
        local info = UIDropDownMenu_CreateInfo(); info.text = L["Follow Main Addon"]; info.func = function() SGF.SelectedProfile = "Global"; SGF.CalculateLabScore() end; info.checked = (SGF.SelectedProfile == "Global" or SGF.SelectedProfile == nil); UIDropDownMenu_AddButton(info, level)
        if MSC.CurrentClass and MSC.CurrentClass.Weights then for k, v in pairs(MSC.CurrentClass.Weights) do local info = UIDropDownMenu_CreateInfo(); local pretty = (MSC.CurrentClass.PrettyNames and MSC.CurrentClass.PrettyNames[k]) or k; info.text = pretty; info.func = function() SGF.SelectedProfile = k; SGF.CalculateLabScore() end; info.checked = (SGF.SelectedProfile == k); UIDropDownMenu_AddButton(info, level) end end
    end)

    -- Add items to the active set
    local hAdd = Header(L["Add to Active Set"], profLbl, -46)
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

    -- Manage both sets
    local hManage = Header(L["Manage"], f.ImpStrBtn, -14)
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
        p:SetPoint("TOPLEFT", dollX[setIdx] - 10, -8); p:SetSize(DOLL_W + 20, 450)
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
            btn:SetScript("OnClick", function(self, button)
                local t,_,l = GetCursorInfo()
                if t=="item" then SGF.ActiveSet = setIdx; UpdateActiveSetUI(); SGF.ReceiveLink(l); ClearCursor()
                elseif button == "RightButton" or IsShiftKeyDown() then SGF.LabItems[setIdx][slotName] = nil; SGF.UpdateLabSlot(slotName, setIdx); SGF.CalculateLabScore() end
            end)
            btn:SetScript("OnEnter", function(s) if s.link then GameTooltip:SetOwner(s,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(s.link); GameTooltip:Show() end; btn.Border:Show() end)
            btn:SetScript("OnLeave", function() GameTooltip_Hide(); btn.Border:Hide() end)
            f.Slots[setIdx][slotName] = btn
        end
    end

    -- Scores under each set, the difference centred under both
    local scoreY = DOLL_TOP - 304 - 34 - 18
    f.ScoreVal1 = C:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal1:SetPoint("TOP", C, "TOPLEFT", dollX[1] + DOLL_W / 2, scoreY); f.ScoreVal1:SetText("0"); f.ScoreVal1:SetTextColor(1,1,0)
    f.ScoreVal2 = C:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge"); f.ScoreVal2:SetPoint("TOP", C, "TOPLEFT", dollX[2] + DOLL_W / 2, scoreY); f.ScoreVal2:SetText("0"); f.ScoreVal2:SetTextColor(1,1,0)

    f.DiffVal = C:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge"); f.DiffVal:SetPoint("TOP", C, "TOP", 0, scoreY - 64); f.DiffVal:SetText(L["Ready"])

    local slotHint = C:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotHint:SetPoint("BOTTOM", 0, 12); slotHint:SetText(L["Right-click or shift-click a slot to empty it"]); slotHint:SetTextColor(0.5, 0.5, 0.5)

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
end

function SGF.UpdateLaboratory() end

-- [[ 6. HOOKS ]]
local regFrame = CreateFrame("Frame")
regFrame:RegisterEvent("PLAYER_LOGIN")
regFrame:SetScript("OnEvent", function()
    local MSC = _G.MSC 
    if not SGJ_LaboratoryDB then SGJ_LaboratoryDB = {} end
    if MSC and MSC.RegisterPluginTab then 
        MSC.RegisterPluginTab(L["The Lab"], "Interface\\Icons\\INV_Chest_Plate04", SGF.InitLaboratoryView, "ViewLaboratory", "UpdateLaboratory")
        if MSC.RenderSidebarButtons then MSC.RenderSidebarButtons() end
        
        if type(SetItemRef) == "function" then
            hooksecurefunc("SetItemRef", function(link) if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then SGF.ReceiveLink(link) end end)
        end
        if type(ContainerFrameItemButton_OnModifiedClick) == "function" then
            hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self) 
                if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then 
                    local b,s = self:GetParent():GetID(), self:GetID()
                    local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(b,s) or GetContainerItemLink(b,s)
                    if l then SGF.ReceiveLink(l) end 
                end 
            end)
        end
        if type(ContainerFrameItemButtonTemplate_OnModifiedClick) == "function" then
            hooksecurefunc("ContainerFrameItemButtonTemplate_OnModifiedClick", function(self) 
                if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then 
                    local b,s = self:GetParent():GetID(), self:GetID()
                    local l = (C_Container and C_Container.GetContainerItemLink) and C_Container.GetContainerItemLink(b,s) or GetContainerItemLink(b,s)
                    if l then SGF.ReceiveLink(l) end 
                end 
            end)
        end
        if type(PaperDollItemSlotButton_OnModifiedClick) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_OnModifiedClick", function(self) if MSC.ViewLaboratory and MSC.ViewLaboratory:IsShown() and IsModifiedClick("CHATLINK") then local link = GetInventoryItemLink("player", self:GetID()); if link then SGF.ReceiveLink(link) end end end)
        end
    end
end)