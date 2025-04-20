local QBCore = exports['qb-core']:GetCoreObject()


QBCore.Functions.CreateCallback('qb-WindPower:server:IsLocationOwned', function(source, cb, coords)
    exports.oxmysql:execute('SELECT id FROM windpower_stations WHERE location = ?', {
        json.encode(coords)
    }, function(result)
        cb(result and #result > 0)
    end)
end)


local function NotifyPlayer(source, message, type)
    if Config.Notify == "qb" then
        TriggerClientEvent('QBCore:Notify', source, message, type)
    elseif Config.Notify == "ox" then
        TriggerClientEvent('ox_lib:notify', source, {
            description = message,
            type = type
        })
    end
end


local function SendWebhook(title, description, color)
    if not Config.Webhooks.enabled or not Config.Webhooks.url or Config.Webhooks.url == "" then return end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = description,
            ["color"] = color or Config.Webhooks.color,
            ["footer"] = {
                ["text"] = Config.Webhooks.footer
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }
    }
    
    PerformHttpRequest(Config.Webhooks.url, function(err, text, headers) end, 'POST', json.encode({
        username = 'Power Station System',
        embeds = embed
    }), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent('qb-WindPower:server:BuyStation')
AddEventHandler('qb-WindPower:server:BuyStation', function(locationIndex)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local location = Config.PowerStations.locations[locationIndex]
    if not location then 
        NotifyPlayer(src, "Invalid location!", "error")
        return 
    end

    exports.oxmysql:execute('SELECT id FROM windpower_stations WHERE location = ?', {
        json.encode(location.coords)
    }, function(existingStation)
        if existingStation and #existingStation > 0 then
            NotifyPlayer(src, "This location is already owned!", "error")
            return
        end

        exports.oxmysql:execute('SELECT COUNT(*) as count FROM windpower_stations WHERE owner = ?', {
            Player.PlayerData.citizenid
        }, function(result)
            if result[1].count >= Config.PowerStations.maxStations then
                NotifyPlayer(src, "You cannot own more power stations!", "error")
                return
            end

            if Player.Functions.RemoveMoney('bank', location.price, "Bought Power Station") then
                exports.oxmysql:insert('INSERT INTO windpower_stations (owner, location, level, production) VALUES (?, ?, ?, ?)', {
                    Player.PlayerData.citizenid,
                    json.encode(location.coords),
                    1,
                    Config.PowerStations.upgrades[1].production
                }, function(id)
                    if id then
                        NotifyPlayer(src, "Successfully purchased power station!", "success")
                        TriggerClientEvent('qb-WindPower:client:UpdateStations', src)
                        
                        if Config.Webhooks.events.purchase then
                            SendWebhook(
                                "Power Station Purchased",
                                string.format("Player: %s\nLocation: %s\nPrice: $%s", 
                                    GetPlayerName(src),
                                    json.encode(location.coords),
                                    location.price
                                )
                            )
                        end
                    else
                        Player.Functions.AddMoney('bank', location.price, "Refund failed station purchase")
                        NotifyPlayer(src, "Failed to purchase station!", "error")
                    end
                end)
            else
                NotifyPlayer(src, "You cannot afford this station!", "error")
            end
        end)
    end)
end)

RegisterServerEvent('qb-WindPower:server:UpgradeStation')
AddEventHandler('qb-WindPower:server:UpgradeStation', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] then
            local currentLevel = result[1].level
            local nextLevel = currentLevel + 1

            if Config.PowerStations.upgrades[nextLevel] then
                local upgradeCost = Config.PowerStations.upgrades[nextLevel].price

                if Player.Functions.RemoveMoney('bank', upgradeCost, "Power Station Upgrade") then
                    exports.oxmysql:execute('UPDATE windpower_stations SET level = ?, production = ? WHERE id = ?', {
                        nextLevel,
                        Config.PowerStations.upgrades[nextLevel].production,
                        stationId
                    }, function()
                        NotifyPlayer(src, "Successfully upgraded power station!", "success")
                        TriggerClientEvent('qb-WindPower:client:UpdateStations', src)
                    end)
                end
            else
                NotifyPlayer(src, "Maximum level reached!", "error")
            end
        end
    end)
end)


RegisterServerEvent('qb-WindPower:server:SellToPlayer')
AddEventHandler('qb-WindPower:server:SellToPlayer', function(targetId, price, stationId)
    local src = source
    local seller = QBCore.Functions.GetPlayer(src)
    local buyer = QBCore.Functions.GetPlayer(tonumber(targetId))
    
    if not seller or not buyer then 
        NotifyPlayer(src, "Invalid player!", "error")
        return 
    end

    exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        seller.PlayerData.citizenid
    }, function(result)
        if result[1] then
            exports.oxmysql:execute('SELECT COUNT(*) as count FROM windpower_stations WHERE owner = ?', {
                buyer.PlayerData.citizenid
            }, function(buyerStations)
                if buyerStations[1].count >= Config.PowerStations.maxStations then
                    NotifyPlayer(src, "Buyer has reached maximum stations limit!", "error")
                    return
                end

                if buyer.Functions.RemoveMoney('bank', price, "Bought Power Station") then
                    seller.Functions.AddMoney('bank', price, "Sold Power Station")
                    
                    exports.oxmysql:execute('UPDATE windpower_stations SET owner = ? WHERE id = ?', {
                        buyer.PlayerData.citizenid,
                        stationId
                    })

                    NotifyPlayer(src, "Successfully sold station for $" .. price, "success")
                    NotifyPlayer(targetId, "Successfully purchased station for $" .. price, "success")
                    
                    TriggerClientEvent('qb-WindPower:client:UpdateStations', src)
                    TriggerClientEvent('qb-WindPower:client:UpdateStations', targetId)
                else
                    NotifyPlayer(src, "Buyer cannot afford this station!", "error")
                end
            end)
        end
    end)
end)


RegisterServerEvent('qb-WindPower:server:RequestSale')
AddEventHandler('qb-WindPower:server:RequestSale', function(targetId, price, stationId)
    local src = source
    local seller = QBCore.Functions.GetPlayer(src)
    local buyer = QBCore.Functions.GetPlayer(tonumber(targetId))
    
    if not seller or not buyer then 
        NotifyPlayer(src, "Invalid player!", "error")
        return 
    end


    if src == tonumber(targetId) then
        NotifyPlayer(src, "You cannot sell the station to yourself!", "error")
        return
    end


    exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        seller.PlayerData.citizenid
    }, function(result)
        if result[1] then

            TriggerClientEvent('qb-WindPower:client:ShowConfirmBuy', buyer.PlayerData.source, src, price, stationId)
            NotifyPlayer(src, "Waiting for buyer confirmation...", "info")
        end
    end)
end)


RegisterServerEvent('qb-WindPower:server:ConfirmPurchase')
AddEventHandler('qb-WindPower:server:ConfirmPurchase', function(sellerId, price, stationId, confirmed)
    local src = source
    local buyer = QBCore.Functions.GetPlayer(src)
    local seller = QBCore.Functions.GetPlayer(sellerId)
    
    if not confirmed then
        NotifyPlayer(sellerId, "Buyer declined the purchase", "error")
        NotifyPlayer(src, "You declined the purchase", "error")
        return
    end


    if buyer.PlayerData.money.bank < price then
        NotifyPlayer(src, "You cannot afford this station!", "error")
        NotifyPlayer(sellerId, "The buyer cannot afford the station!", "error")
        return
    end


    TriggerEvent('qb-WindPower:server:SellToPlayer', sellerId, src, price, stationId)
end)


RegisterServerEvent('qb-WindPower:server:SellStation')
AddEventHandler('qb-WindPower:server:SellStation', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] then
            local refundAmount = math.floor(Config.PowerStations.basePrice * 0.4)
            Player.Functions.AddMoney('bank', refundAmount, "Power Station Refund")
            
            exports.oxmysql:execute('DELETE FROM windpower_stations WHERE id = ?', {stationId})
            
            NotifyPlayer(src, "Successfully sold station for $" .. refundAmount, "success")
            TriggerClientEvent('qb-WindPower:client:UpdateStations', src)
        end
    end)
end)


QBCore.Functions.CreateCallback('qb-WindPower:server:GetPlayerStations', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end

    exports.oxmysql:execute([[
        SELECT 
            vs.*,
            COALESCE(
                (SELECT SUM(production) 
                FROM windpower_stations 
                WHERE owner = ? AND level > 0), 
            0) as total_production
        FROM windpower_stations vs 
        WHERE vs.owner = ?
    ]], {
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid
    }, function(results)
        for i, station in ipairs(results) do
            station.coords = json.decode(station.location)
            station.upgrade_cost = Config.PowerStations.upgrades[station.level + 1] and 
            Config.PowerStations.upgrades[station.level + 1].price or 0
        end
        cb(results)
    end)
end)


QBCore.Functions.CreateCallback('qb-WindPower:server:GetStationInfo', function(source, cb, coords)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(nil) end

    exports.oxmysql:execute('SELECT id, level, production, status, health, battery FROM windpower_stations WHERE location = ? AND owner = ?', {
        json.encode(coords),
        Player.PlayerData.citizenid
    }, function(result)
        if result and result[1] then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)


QBCore.Functions.CreateCallback('qb-WindPower:server:GetRepairCost', function(source, cb, stationId)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(0, 0) end

    exports.oxmysql:execute('SELECT health FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] then
            local currentHealth = result[1].health
            local repairCost = math.floor((100 - currentHealth) * 100) 
            cb(repairCost, currentHealth)
        else
            cb(0, 0)
        end
    end)
end)


CreateThread(function()
    while true do
        Wait(Config.PowerStations.moneyInterval * 60 * 1000)
        
        -- Placeholder for weather retrieval
        local currentWeather = "CLEAR" -- Replace this with the actual method to get the current weather
        local isWeatherBad = Config.WeatherImpact.enabled and Config.WeatherImpact.badWeather[currentWeather]
        
        exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE status != ?', {'offline'}, function(stations)
            for _, station in pairs(stations) do
                local earnings = Config.PowerStations.upgrades[station.level].earnings
                
                -- Reduce earnings in bad weather
                if isWeatherBad then
                    earnings = math.floor(earnings * Config.WeatherImpact.productionModifier)
                    -- Update station status to maintenance due to weather
                    exports.oxmysql:execute('UPDATE windpower_stations SET status = ? WHERE id = ? AND status != ?', {
                        'maintenance',
                        station.id,
                        'offline'
                    })
                else
                    -- Restore status to operational if weather is good
                    exports.oxmysql:execute('UPDATE windpower_stations SET status = ? WHERE id = ? AND status = ?', {
                        'operational',
                        station.id,
                        'maintenance'
                    })
                end
                
                exports.oxmysql:execute('UPDATE windpower_stations SET stored_money = stored_money + ? WHERE id = ?', {
                    earnings,
                    station.id
                })
            end

            if Config.Webhooks.events.weather and isWeatherBad then
                SendWebhook(
                    "Weather Impact",
                    string.format("Weather: %s\nAffected Stations: %s\nProduction: %s%%", 
                        currentWeather,
                        #stations,
                        Config.WeatherImpact.productionModifier * 100
                    ),
                    15158332 -- Red for bad weather
                )
            end
        end)
    end
end)

RegisterServerEvent('qb-WindPower:server:CollectMoney')
AddEventHandler('qb-WindPower:server:CollectMoney', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT stored_money FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] and result[1].stored_money > 0 then
            local amount = result[1].stored_money
            Player.Functions.AddMoney('cash', amount, "Power Station Earnings")
            exports.oxmysql:execute('UPDATE windpower_stations SET stored_money = 0 WHERE id = ?', {stationId})
            NotifyPlayer(src, "Collected $" .. amount .. " from your power station!", "success")
        else
            NotifyPlayer(src, "No money to collect!", "error")
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(Config.PowerStations.healthDecay.interval * 60 * 1000) -- Check every X minutes
        exports.oxmysql:execute('SELECT * FROM windpower_stations', {}, function(stations)
            for _, station in pairs(stations) do
                local healthLoss = math.random(
                    Config.PowerStations.healthDecay.amount.min,
                    Config.PowerStations.healthDecay.amount.max
                )
                local newHealth = math.max(0, station.health - healthLoss)
                local newStatus = 'operational'
                
                if newHealth <= 20 then
                    newStatus = 'offline'
                elseif newHealth <= 60 then
                    newStatus = 'maintenance'
                end

                exports.oxmysql:execute('UPDATE windpower_stations SET health = ?, status = ? WHERE id = ?', {
                    newHealth,
                    newStatus,
                    station.id
                })
            end
        end)
    end
end)

RegisterServerEvent('qb-WindPower:server:RepairStation')
AddEventHandler('qb-WindPower:server:RepairStation', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] then
            if result[1].health >= 100 then
                NotifyPlayer(src, "Station is already at full health!", "error")
                return
            end
            
            local repairCost = math.floor((100 - result[1].health) * 100)
            
            if Player.Functions.RemoveMoney('bank', repairCost, "Power Station Repair") then
                exports.oxmysql:execute('UPDATE windpower_stations SET health = 100, status = ? WHERE id = ?', {
                    'operational',
                    stationId
                })
                NotifyPlayer(src, "Station repaired for $" .. repairCost, "success")
                TriggerClientEvent('qb-WindPower:client:UpdateStations', src)

                if Config.Webhooks.events.repair then
                    SendWebhook(
                        "Power Station Repaired",
                        string.format("Player: %s\nStation ID: %s\nRepair Cost: $%s", 
                            GetPlayerName(src),
                            stationId,
                            repairCost
                        )
                    )
                end
            else
                NotifyPlayer(src, "You cannot afford the repair cost: $" .. repairCost, "error")
            end
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(Config.PowerStations.battery.drain.interval * 60 * 1000)
        exports.oxmysql:execute('UPDATE windpower_stations SET battery = GREATEST(0, battery - ?) WHERE battery > 0', {
            Config.PowerStations.battery.drain.amount
        })
    end
end)

RegisterServerEvent('qb-WindPower:server:ChargeBattery')
AddEventHandler('qb-WindPower:server:ChargeBattery', function(stationId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    exports.oxmysql:execute('SELECT battery FROM windpower_stations WHERE id = ? AND owner = ?', {
        stationId,
        Player.PlayerData.citizenid
    }, function(result)
        if result[1] then
            if result[1].battery >= 100 then
                NotifyPlayer(src, "Battery is already fully charged!", "error")
                return
            end

            local hasItem = Player.Functions.RemoveItem(Config.PowerStations.battery.item, 1)
            if hasItem then
                local newBattery = math.min(100, result[1].battery + Config.PowerStations.battery.restore)
                exports.oxmysql:execute('UPDATE windpower_stations SET battery = ? WHERE id = ?', {
                    newBattery,
                    stationId
                })
                NotifyPlayer(src, "Successfully charged station battery!", "success")
                TriggerClientEvent('qb-WindPower:client:UpdateStations', src)
            else
                NotifyPlayer(src, "You don't have a battery!", "error")
            end
        end
    end)
end)


CreateThread(function()
    while true do
        Wait(Config.PowerStations.moneyInterval * 60 * 1000)
        
        exports.oxmysql:execute('SELECT * FROM windpower_stations WHERE status != ?', {'offline'}, function(stations)
            for _, station in pairs(stations) do
                local baseEarnings = Config.PowerStations.upgrades[station.level].earnings
                
                local batteryMod = Config.PowerStations.battery.production.low
                if station.battery >= 75 then
                    batteryMod = Config.PowerStations.battery.production.full
                elseif station.battery >= 50 then
                    batteryMod = Config.PowerStations.battery.production.high
                elseif station.battery >= 25 then
                    batteryMod = Config.PowerStations.battery.production.medium
                end
                
                local earnings = math.floor(baseEarnings * batteryMod)
                
                if station.battery > 0 then
                    exports.oxmysql:execute('UPDATE windpower_stations SET stored_money = stored_money + ? WHERE id = ?', {
                        earnings,
                        station.id
                    })
                end
            end
        end)
    end
end)
