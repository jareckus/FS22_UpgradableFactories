InGameMenuUpgradableFactories = {}
InGameMenuUpgradableFactories._mt = Class(InGameMenuUpgradableFactories, TabbedMenuFrameElement)

InGameMenuUpgradableFactories.CONTROLS = {
    MAIN_BOX = "mainBox",
    TABLE_SLIDER = "tableSlider",
    HEADER_BOX = "tableHeaderBox",
    TABLE = "upgradableFactoriesTable",
    TABLE_TEMPLATE = "upgradableFactoriesRowTemplate",
}

function InGameMenuUpgradableFactories.new(i18n, messageCenter)
    local self = InGameMenuUpgradableFactories:superClass().new(nil, InGameMenuUpgradableFactories._mt)
    
    self.name = "InGameMenuUpgradableFactories"
    self.i18n = i18n
    self.messageCenter = messageCenter
    self.factories = {}
    
    self:registerControls(InGameMenuUpgradableFactories.CONTROLS)
    
    self.backButtonInfo = {
        inputAction = InputAction.MENU_BACK
    }
    self.btnUpgrade = {
        text = "Upgrade",
        inputAction = InputAction.MENU_ACTIVATE,
        callback = function ()
            self:upgrade()
        end
    }
    self.btnSell = {
        text = "Sell",
        inputAction = InputAction.MENU_EXTRA_1,
        callback = function ()
            self:sell()
        end
    }
    
    self:setMenuButtonInfo({
        self.backButtonInfo,
        self.btnUpgrade,
        self.btnSell
    })
    
    return self
end

function InGameMenuUpgradableFactories:initialize()
    self:loadFromXML()
end

function InGameMenuUpgradableFactories:onSavegameLoaded()
    self:lookForPCMFactories()
    self:updatePCMFactoriesRates()
end

function InGameMenuUpgradableFactories:delete()
    InGameMenuUpgradableFactories:superClass().delete(self)
end

function InGameMenuUpgradableFactories:copyAttributes(src)
    InGameMenuUpgradableFactories:superClass().copyAttributes(self, src)
    self.i18n = src.i18n
end

function InGameMenuUpgradableFactories:onGuiSetupFinished()
    InGameMenuUpgradableFactories:superClass().onGuiSetupFinished(self)
    self.upgradableFactoriesTable:setDataSource(self)
    self.upgradableFactoriesTable:setDelegate(self)
end

function InGameMenuUpgradableFactories:onFrameOpen()
    InGameMenuUpgradableFactories:superClass().onFrameOpen(self)
    self.upgradableFactoriesTable:reloadData()
    FocusManager:setFocus(self.upgradableFactoriesTable)
end

function InGameMenuUpgradableFactories:onFrameClose()
    InGameMenuUpgradableFactories:superClass().onFrameClose(self)
end

local function tabLen(tab)
    local n = 0
    for _,_ in pairs(tab) do
        n = n +1
    end
    return n
end

function InGameMenuUpgradableFactories:lookForPCMFactories()
    for _,f in ipairs(g_currentMission.productionChainManager.productionPoints) do
        if f.isOwned and not self:getFactoryById(f.id) then
            local tab = {
                id = f.id,
                name = f:getName(),
                level = 1,
                basePrice = f.owningPlaceable:getPrice(),
                upgradePrice = f.owningPlaceable:getPrice(),
                productions = {},
                baseCapacities = {}
            }

            for _,p in ipairs(f.productions) do
                table.insert(
                    tab.productions,
                    {
                        name = p.name,
                        cyclesPerMonth = p.cyclesPerMonth,
                        costsPerActiveMonth = p.costsPerActiveMonth
                    }
                )
            end

            for fillType,capacity in pairs(f.storage.capacities) do
                table.insert(tab.baseCapacities, fillType, capacity)
            end
            
            table.insert(
                self.factories,
                tab
            )
        end
    end
end

function InGameMenuUpgradableFactories:getFactoryById(id)
    for _,n in ipairs(self.factories) do
        if n.id == id then
            return n
        end
    end
    return nil
end

function InGameMenuUpgradableFactories:getPCMFactoryById(id)
    for _,n in ipairs(g_currentMission.productionChainManager.productionPoints) do
        if n.id == id then
            return n
        end
    end
    return nil
end

function InGameMenuUpgradableFactories:getNumberOfSections()
    return 1
end

function InGameMenuUpgradableFactories:getNumberOfItemsInSection(list, section)
    return #self.factories
end

function InGameMenuUpgradableFactories:getTitleForSectionHeader(list, section)
    return "owned productions"
end

function InGameMenuUpgradableFactories:populateCellForItemInSection(list, section, index, cell)
    local fact = self.factories[index]
    cell:getAttribute("factory"):setText(fact.name)
    cell:getAttribute("level"):setText(fact.level)
    cell:getAttribute("value"):setText(g_i18n:formatMoney(fact.basePrice * fact.level))
    cell:getAttribute("cost"):setText(g_i18n:formatMoney(fact.upgradePrice))
end

function InGameMenuUpgradableFactories:onListSelectionChanged(list, section, index)
    self.selectedFactory = self.factories[index]
end

function InGameMenuUpgradableFactories:upgrade()
    if g_currentMission.missionInfo.money >= self.selectedFactory.basePrice then
        local text = string.format(
            "Upgrade %s for %s?",
            self.selectedFactory.name,
            g_i18n:formatMoney(self.selectedFactory.upgradePrice)
        )
        g_gui:showYesNoDialog(
            {
                text = text,
                title = "Upgrade Factory",
                callback = self.onUpgradeConfirm,
                target = self
            }
        )
    end
end

function InGameMenuUpgradableFactories:onUpgradeConfirm(confirm)
    if confirm then
        g_currentMission:addMoney(-self.selectedFactory.upgradePrice, 1--[[farmId]], MoneyType.SHOP_PROPERTY_BUY, true, true)
        self.selectedFactory.level = self.selectedFactory.level + 1
        self.selectedFactory.upgradePrice = self:adjUpgradePrice2lvl(self.selectedFactory.basePrice, self.selectedFactory.level)
        self.upgradableFactoriesTable:reloadData()
        self:updatePCMFactoriesRates()
    end
end

function InGameMenuUpgradableFactories:adjUpgradePrice2lvl(price, lvl)
    -- Upgrade price increase by 7.5% each level
    return price * (1 + (0.075 * (lvl - 1)))
end

function InGameMenuUpgradableFactories:adjCapa2lvl(capacity, lvl)
    -- Strorage capacity increase by 2.5 times the base capacity each level
    return capacity + capacity * 2.5 * (lvl - 1)
end

function InGameMenuUpgradableFactories:adjCycl2lvl(cycle, lvl)
    -- Production speed gets multiplied by the level and 5% faster each time
    return cycle * lvl * (1 + (0.05 * (lvl - 1)))
end

function InGameMenuUpgradableFactories:adjCost2lvl(cost, lvl)
    -- Running cost gets multiplied by the level and is slightly cheaper each time by 5%
    return cost + cost * 0.95 * (lvl - 1)
end

function InGameMenuUpgradableFactories:adjSellPrice2lvl(price, lvl)
    -- Sell price is 75% of facotry's value (base is 50%)
    return price * lvl * 0.75
end

function InGameMenuUpgradableFactories:updatePCMFactoriesRates()
    for _,f in ipairs(self.factories) do
        local pcm = self:getPCMFactoryById(f.id)
        for i,pcmp in ipairs(pcm.productions) do
            local fp = f.productions[i]
            
            if not fp or pcmp.name ~= fp.name then
                for j,n in ipairs(f.productions) do
                    if n.name == pcmp.name then
                        fp = f.productions[j]
                    end
                end

                if not fp or pcmp.name ~= fp.name then
                    print("Error while updating "..pcmp.name.." factory "..fp)
                    break
                end
            end

            pcmp.cyclesPerMonth = self:adjCycl2lvl(fp.cyclesPerMonth, f.level)
            pcmp.cyclesPerHour = pcmp.cyclesPerMonth / 24
            pcmp.cyclesPerMinute = pcmp.cyclesPerHour / 60

            pcmp.costsPerActiveMonth = self:adjCost2lvl(fp.costsPerActiveMonth, f.level)
            pcmp.costsPerActiveHour = pcmp.costsPerActiveMonth / 24
            pcmp.costsPerActiveMinute = pcmp.costsPerActiveHour / 60
        end

        local pcmc = pcm.storage.capacities
        for fillType,capacity in pairs(pcm.storage.capacities) do
            pcmc[fillType] = self:adjCapa2lvl(capacity, f.level)
        end

        -- pcm.owningPlaceable.price = f.basePrice * f.level
        pcm.owningPlaceable.getSellPrice = Utils.overwrittenFunction(
            pcm.owningPlaceable.getSellPrice,
            function ()
                return self:adjSellPrice2lvl(f.basePrice, f.level)
            end
        )
    end
end

function InGameMenuUpgradableFactories:sell()
    print("WIP")
end

function InGameMenuUpgradableFactories:saveToXML(xmlFile)
    self:lookForPCMFactories()
    
    local key = ""
    
    for i,n in ipairs(self.factories) do
        key = string.format("upgradableFactories.factory(%d)", i)
        xmlFile:setInt(key .. "#id", n.id)
        xmlFile:setString(key .. "#name", n.name)
        xmlFile:setInt(key .. "#level", n.level)
        xmlFile:setInt(key .. "#basePrice", n.basePrice)
        xmlFile:setInt(key .. "#upgradePrice", n.upgradePrice)
        
        local j = 0
        local key2 = ""
        for _,p in ipairs(n.productions) do
            key2 = key .. string.format(".productions.production(%d)", j)
            xmlFile:setString(key2 .. "#name", p.name)
            xmlFile:setInt(key2 .. "#cyclesPerMonth", p.cyclesPerMonth)
            xmlFile:setInt(key2 .. "#costsPerActiveMonth", p.costsPerActiveMonth)
            j = j + 1
        end

        j = 0
        key2 = ""
        for k,v in pairs(n.baseCapacities) do
            key2 = key .. string.format(".capacities.baseCapacity(%d)", j)
            xmlFile:setInt(key2 .. "#fillType", k)
            xmlFile:setInt(key2 .. "#capacity", v)
            j = j + 1
        end
    end
end

function InGameMenuUpgradableFactories:loadFromXML()
    local xmlFile = loadXMLFile("UpgradableFactoriesXML", UpgradableFactories.xmlFilename)

    if xmlFile == 0 then
        return
    end

    local counter = 1
    while true do
        local key = string.format("upgradableFactories.factory(%d)", counter)
        local id = getXMLInt(xmlFile, key .. "#id")
        
        if not id then
            break
        end

        local name = getXMLString(xmlFile, key .. "#name")
        local level = getXMLInt(xmlFile, key .. "#level")
        local basePrice = getXMLInt(xmlFile, key .. "#basePrice")
        local upgradePrice = getXMLInt(xmlFile, key .. "#upgradePrice")
        local productions = {}
        local baseCapacities = {}

        local counter2 = 0
        while true do
            local key2 = key .. string.format(".productions.production(%d)", counter2)
            
            local name = getXMLString(xmlFile, key2 .. "#name")
            local cypm = getXMLInt(xmlFile, key2 .. "#cyclesPerMonth")
            local copm = getXMLInt(xmlFile, key2 .. "#costsPerActiveMonth")
            if not (name and cypm and copm) then
                break
            end

            table.insert(
                productions,
                {
                    name = name,
                    cyclesPerMonth = cypm,
                    costsPerActiveMonth = copm
                }
            )

            counter2 = counter2 +1
        end

        counter2 = 0
        while true do
            local key2 = key .. string.format(".capacities.baseCapacity(%d)", counter2)
            
            local fillType = getXMLInt(xmlFile, key2 .. "#fillType")
            local capacity = getXMLInt(xmlFile, key2 .. "#capacity")
            if not fillType or not capacity then
                break
            end

            table.insert(baseCapacities, fillType, capacity)

            counter2 = counter2 +1
        end

        if name and level and basePrice and upgradePrice then
            table.insert(
                self.factories,
                {
                    id = id,
                    name = name,
                    level = level,
                    basePrice = basePrice,
                    upgradePrice = upgradePrice,
                    productions = productions,
                    baseCapacities = baseCapacities
                }
            )
        end
        
        counter = counter +1
    end

    delete(xmlFile)
end

-- TODO
-- add default values to xml loading to avoid bugs due to missing values (-> XMLUtil)
-- implement "sell" method
-- remove the sections of the gui production table. the table is divided into a single section (titled "owned production") => useless usage of sections
-- (x) modify cycle cost, prod rate & storage capacity based on factory level & overwrite factory sell price
-- (x) rename "upgradable production" to "upgradable factory" (a factory hold 1 or more productions)

-- BUG
-- Error when creating a new savegame (attempt to access the savegame directory that does not exist)
-- first factory in the xml file is empty : <factory/>

-- FEATURE
-- add a "rename factory" button
-- add a "downgrade factory" button

--[[
    prod_rate(level) = base_prod_rate * level * (1 + (0.1 * (level - 1)))
    10% bonus prod rate / level (0% lvl 1, 10% level 2, 20% level 3...)
]]