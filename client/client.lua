local QBCore = exports['qb-core']:GetCoreObject()
local ped = nil
local playerStations = {}
local stationBlips = {}
local availableBlips = {}
local showingAvailable = false


local function Notify(message, type)
    if Config.Notify == "qb" then
        QBCore.Functions.Notify(message, type)
    elseif Config.Notify == "ox" then
        lib.notify({
            description = message,
            type = type
        })
    end
end


local function OpenMenu(menuItems)
    if Config.Menu == "qb" then
        exports['qb-menu']:openMenu(menuItems)
    elseif Config.Menu == "ox" then
        local options = {}
        for _, item in pairs(menuItems) do
            if not item.isMenuHeader then
                table.insert(options, {
                    title = item.header,
                    description = item.txt,
                    icon = item.icon,
                    onSelect = item.params and (item.params.isAction and item.params.event or function()
                        TriggerEvent(item.params.event, item.params.args)
                    end),
                    disabled = item.disabled,
                    metadata = item.metadata
                })
            end
        end

        lib.registerContext({
            id = 'voltage_menu',
            title = menuItems[1].header,
            onExit = function()
            end,
            options = options
        })

        lib.showContext('voltage_menu')
    end
end



function LoadPlayerStations()
    QBCore.Functions.TriggerCallback('qb-WindPower:server:GetPlayerStations', function(stations)
        UpdateStationBlips(stations)
    end)
end


AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(2000) 
        LoadPlayerStations()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, blip in pairs(stationBlips) do
            RemoveBlip(blip)
        end
        stationBlips = {}
    end
end)


CreateThread(function()
    for _, manager in pairs(Config.Managers) do
        RequestModel(manager.model)
        while not HasModelLoaded(manager.model) do
            Wait(0)
        end
        
        local ped = CreatePed(4, manager.model, manager.location.x, manager.location.y, manager.location.z - 1, manager.location.w, false, true)
        SetEntityHeading(ped, manager.location.w)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        
        Wait(1000)
        
        if DoesEntityExist(ped) then
            if Config.Target == "qb" then
                exports['qb-target']:AddTargetEntity(ped, {
                    options = {
                        {
                            type = "client",
                            event = "qb-WindPower:client:OpenManagerMenu",
                            icon = "fas fa-bolt",
                            label = "Manage Power Stations",
                        },
                        {
                            type = "client",
                            event = "qb-WindPower:client:ToggleAvailableStations",
                            icon = "fas fa-map-marker",
                            label = "Toggle Available Stations",
                        }
                    },
                    distance = 2.0
                })
            elseif Config.Target == "ox" then
                exports.ox_target:addLocalEntity(ped, {
                    {
                        name = manager.name,
                        label = 'Manage Power Stations',
                        icon = 'fas fa-bolt',
                        onSelect = function()
                            TriggerEvent('qb-WindPower:client:OpenManagerMenu')
                        end,
                        distance = 2.0,
                    },
                    {
                        name = manager.name .. '_available',
                        label = 'Toggle Available Stations',
                        icon = 'fas fa-map-marker',
                        onSelect = function()
                            TriggerEvent('qb-WindPower:client:ToggleAvailableStations')
                        end,
                        distance = 2.0,
                    }
                })
            end
        else
            print('Error: Failed to create ped for voltage seller')
        end

        local pedBlip = AddBlipForCoord(manager.location.x, manager.location.y, manager.location.z)
        SetBlipSprite(pedBlip, Config.Blips.Ped.sprite)
        SetBlipDisplay(pedBlip, 4)
        SetBlipScale(pedBlip, Config.Blips.Ped.scale)
        SetBlipColour(pedBlip, Config.Blips.Ped.color)
        SetBlipAsShortRange(pedBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.Ped.label)
        EndTextCommandSetBlipName(pedBlip)
    end
end)


CreateThread(function()
    for k, v in pairs(Config.PowerStations.locations) do
        if Config.Target == "qb" then
            exports['qb-target']:AddBoxZone(
                'power_station_' .. k,
                v.coords,
                2.0,
                2.0,
                {
                    name = 'power_station_' .. k,
                    heading = 0,
                    debugPoly = false,
                    minZ = v.coords.z - 1,
                    maxZ = v.coords.z + 1,
                },
                {
                    options = {
                        {
                            type = "client",
                            action = function()
                                local coords = GetEntityCoords(PlayerPedId())
                                if #(coords - v.coords) <= 3.0 then
                                    if Config.Menu == "ox" then
                                        local confirm = lib.alertDialog({
                                            header = 'Purchase Power Station',
                                            content = string.format('Are you sure you want to buy this power station for $%d?', v.price),
                                            cancel = true,
                                            labels = {
                                                confirm = 'Yes',
                                                cancel = 'No'
                                            }
                                        })
                                        if confirm == 'confirm' then
                                            TriggerServerEvent('qb-WindPower:server:BuyStation', k)
                                        end
                                    else
                                        local menuItems = {
                                            {
                                                header = "Purchase Power Station",
                                                txt = ("Price: $%d"):format(v.price),
                                                icon = 'fas fa-bolt',
                                                isMenuHeader = true
                                            },
                                            {
                                                header = "Confirm Purchase",
                                                txt = "Buy this power station",
                                                icon = 'fas fa-check',
                                                params = {
                                                    isAction = true,
                                                    event = function()
                                                        TriggerServerEvent('qb-WindPower:server:BuyStation', k)
                                                    end
                                                }
                                            },
                                            {
                                                header = "Cancel",
                                                txt = "Cancel purchase",
                                                icon = 'fas fa-xmark',
                                                params = {
                                                    event = "qb-menu:closeMenu"
                                                }
                                            }
                                        }
                                        exports['qb-menu']:openMenu(menuItems)
                                    end
                                else
                                    Notify('You are too far from the location', 'error')
                                end
                            end,
                            icon = "fas fa-bolt",
                            label = "Purchase Power Station ($" .. v.price .. ")",
                            canInteract = function()
                                return not IsLocationOwned(v.coords)
                            end
                        },
                        {
                            type = "client",
                            action = function()
                                QBCore.Functions.TriggerCallback('qb-WindPower:server:GetStationInfo', function(stationInfo)
                                    if stationInfo then
                                        local statusText = "~g~OPERATIONAL~w~"
                                        if stationInfo.status == 'maintenance' then
                                            statusText = "~y~MAINTENANCE~w~"
                                        elseif stationInfo.status == 'offline' then
                                            statusText = "~r~OFFLINE~w~"
                                        end

                                        if Config.Menu == "qb" then
                                            local menuItems = {
                                                {
                                                    header = "Station #" .. stationInfo.id,
                                                    icon = 'fas fa-bolt',
                                                    txt = ("Level: %d | Production: %d%%/hr\nStatus: %s\nHealth: %d%%"):format(
                                                        stationInfo.level, 
                                                        stationInfo.production,
                                                        statusText,
                                                        stationInfo.health
                                                    ),
                                                    isMenuHeader = true
                                                },
                                                {
                                                    header = "Close",
                                                    icon = 'fas fa-xmark',
                                                    params = {
                                                        event = "qb-menu:closeMenu"
                                                    }
                                                }
                                            }
                                            exports['qb-menu']:openMenu(menuItems)
                                        elseif Config.Menu == "ox" then
                                            local statusColor = {
                                                operational = "92a65f", -- Green hex
                                                maintenance = "c3a758", -- Yellow hex
                                                offline = "a65f5f"      -- Red hex
                                            }
                                            
                                            local healthColor = stationInfo.health > 70 and "92a65f" or stationInfo.health > 30 and "c3a758" or "a65f5f"
                                            
                                            lib.registerContext({
                                                id = 'voltage_info',
                                                title = "Station #" .. stationInfo.id,
                                                menu = 'voltage_main',
                                                options = {
                                                    {
                                                        title = "Station Information",
                                                        description = ("Level: %d | Production: %d%%/hr\nStatus: [%s]\nHealth: %d%%"):format(
                                                            stationInfo.level, 
                                                            stationInfo.production,
                                                            stationInfo.status:upper(),
                                                            stationInfo.health
                                                        ),
                                                        icon = 'fas fa-bolt',
                                                        iconColor = statusColor[stationInfo.status] or "ffffff",
                                                        disabled = true,
                                                        metadata = {
                                                            {label = 'Health', value = stationInfo.health .. '%', progress = stationInfo.health}
                                                        }
                                                    }
                                                }
                                            })
                                            lib.showContext('voltage_info')
                                        end
                                    end
                                end, v.coords)
                            end,
                            icon = "fas fa-info-circle",
                            label = "View Station Info",
                            canInteract = function()
                                return IsLocationOwned(v.coords)
                            end
                        }
                    },
                    distance = 2.0
                }
            )
        elseif Config.Target == "ox" then
            exports['ox_target']:addSphereZone({
                coords = v.coords,
                radius = 2.0,
                options = {
                    {
                        name = 'power_station_' .. k,
                        label = 'Purchase Power Station ($' .. v.price .. ')',
                        icon = 'fas fa-bolt',
                        canInteract = function()
                            local owned = IsLocationOwned(v.coords)
                            return not owned
                        end,
                        onSelect = function()
                            local coords = GetEntityCoords(PlayerPedId())
                            if #(coords - v.coords) <= 3.0 then
                                if Config.Menu == "ox" then
                                    local confirm = lib.alertDialog({
                                        header = 'Purchase Power Station',
                                        content = string.format('Are you sure you want to buy this power station for $%d?', v.price),
                                        cancel = true,
                                        labels = {
                                            confirm = 'Yes',
                                            cancel = 'No'
                                        }
                                    })
                                    if confirm == 'confirm' then
                                        TriggerServerEvent('qb-WindPower:server:BuyStation', k)
                                    end
                                else
                                    local menuItems = {
                                        {
                                            header = "Purchase Power Station",
                                            txt = ("Price: $%d"):format(v.price),
                                            icon = 'fas fa-bolt',
                                            isMenuHeader = true
                                        },
                                        {
                                            header = "Confirm Purchase",
                                            txt = "Buy this power station",
                                            icon = 'fas fa-check',
                                            params = {
                                                isAction = true,
                                                event = function()
                                                    TriggerServerEvent('qb-WindPower:server:BuyStation', k)
                                                end
                                            }
                                        },
                                        {
                                            header = "Cancel",
                                            txt = "Cancel purchase",
                                            icon = 'fas fa-xmark',
                                            params = {
                                                event = "qb-menu:closeMenu"
                                            }
                                        }
                                    }
                                    exports['qb-menu']:openMenu(menuItems)
                                end
                            else
                                Notify('You are too far from the location', 'error')
                            end
                        end
                    },
                    {
                        name = 'power_station_info_' .. k,
                        label = 'View Station Info',
                        icon = 'fas fa-info-circle',
                        canInteract = function()
                            local owned = IsLocationOwned(v.coords)
                            return owned
                        end,
                        onSelect = function()
                            QBCore.Functions.TriggerCallback('qb-WindPower:server:GetStationInfo', function(stationInfo)
                                if stationInfo then
                                    local statusText = "~g~OPERATIONAL~w~"
                                    if stationInfo.status == 'maintenance' then
                                        statusText = "~y~MAINTENANCE~w~"
                                    elseif stationInfo.status == 'offline' then
                                        statusText = "~r~OFFLINE~w~"
                                    end

                                    if Config.Menu == "qb" then
                                        local menuItems = {
                                            {
                                                header = "Station #" .. stationInfo.id,
                                                icon = 'fas fa-bolt',
                                                txt = ("Level: %d | Production: %d%%/hr\nStatus: %s\nHealth: %d%%"):format(
                                                    stationInfo.level, 
                                                    stationInfo.production,
                                                    statusText,
                                                    stationInfo.health
                                                ),
                                                isMenuHeader = true
                                            },
                                            {
                                                header = "Close",
                                                icon = 'fas fa-xmark',
                                                params = {
                                                    event = "qb-menu:closeMenu"
                                                }
                                            }
                                        }
                                        exports['qb-menu']:openMenu(menuItems)
                                    elseif Config.Menu == "ox" then
                                        local statusColor = {
                                            operational = "92a65f", -- Green hex
                                            maintenance = "c3a758", -- Yellow hex
                                            offline = "a65f5f"      -- Red hex
                                        }
                                        
                                        local healthColor = stationInfo.health > 70 and "92a65f" or stationInfo.health > 30 and "c3a758" or "a65f5f"
                                        
                                        lib.registerContext({
                                            id = 'voltage_info',
                                            title = "Station #" .. stationInfo.id,
                                            menu = 'voltage_main',
                                            options = {
                                                {
                                                    title = "Station Information",
                                                    description = ("Level: %d | Production: %d%%/hr\nStatus: [%s]\nHealth: %d%%"):format(
                                                        stationInfo.level, 
                                                        stationInfo.production,
                                                        stationInfo.status:upper(),
                                                        stationInfo.health
                                                    ),
                                                    icon = 'fas fa-bolt',
                                                    iconColor = statusColor[stationInfo.status] or "ffffff",
                                                    disabled = true,
                                                    metadata = {
                                                        {label = 'Health', value = stationInfo.health .. '%', progress = stationInfo.health}
                                                    }
                                                }
                                            }
                                        })
                                        lib.showContext('voltage_info')
                                    end
                                end
                            end, v.coords)
                        end
                    }
                }
            })
        end
    end
end)


function IsLocationOwned(coords)
    local owned = false
    local done = false
    
    QBCore.Functions.TriggerCallback('qb-WindPower:server:IsLocationOwned', function(result)
        owned = result
        done = true
    end, coords)
    
    while not done do
        Wait(0)
    end
    
    return owned
end


function UpdateStationBlips(stations)

    for _, blip in pairs(stationBlips) do
        RemoveBlip(blip)
    end
    stationBlips = {}


    for _, station in pairs(stations) do
        local coords = json.decode(station.location)
        local stationBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(stationBlip, Config.Blips.PowerStation.sprite)
        SetBlipDisplay(stationBlip, 4)
        SetBlipScale(stationBlip, Config.Blips.PowerStation.scale)
        SetBlipColour(stationBlip, Config.Blips.PowerStation.color)
        SetBlipAsShortRange(stationBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.PowerStation.label .. " #" .. station.id)
        EndTextCommandSetBlipName(stationBlip)
        table.insert(stationBlips, stationBlip)
    end
end


function ToggleAvailableStations(show)
    if show then
        for k, v in pairs(Config.PowerStations.locations) do
            if not IsLocationOwned(v.coords) then
                local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
                SetBlipSprite(blip, Config.Blips.Available.sprite)
                SetBlipDisplay(blip, 4)
                SetBlipScale(blip, Config.Blips.Available.scale)
                SetBlipColour(blip, Config.Blips.Available.color)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(Config.Blips.Available.label .. " ($" .. v.price .. ")")
                EndTextCommandSetBlipName(blip)
                table.insert(availableBlips, blip)
            end
        end
        showingAvailable = true
    else
        for _, blip in pairs(availableBlips) do
            RemoveBlip(blip)
        end
        availableBlips = {}
        showingAvailable = false
    end
end


RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    LoadPlayerStations()
end)


RegisterNetEvent('qb-WindPower:client:UpdateStations')
AddEventHandler('qb-WindPower:client:UpdateStations', function()
    QBCore.Functions.TriggerCallback('qb-WindPower:server:GetPlayerStations', function(stations)
        UpdateStationBlips(stations)
    end)
end)

function GetAngleBetweenVectors(v1, v2)
    return math.deg(math.acos(
        (v1.x * v2.x + v1.y * v2.y) /
        (math.sqrt(v1.x * v1.x + v1.y * v1.y) * math.sqrt(v2.x * v2.x + v2.y * v2.y))
    ))
end


RegisterNetEvent('qb-WindPower:client:UpgradeStation')
AddEventHandler('qb-WindPower:client:UpgradeStation', function(data)
    TriggerServerEvent('qb-WindPower:server:UpgradeStation', data.stationId)
end)


RegisterNetEvent('qb-WindPower:client:StationOptions')
AddEventHandler('qb-WindPower:client:StationOptions', function(data)
    local menuItems = {
        {
            header = "Station #" .. data.stationId,
            icon = 'fas fa-bolt',
            txt = ("Level: %d | Production: %d/hr"):format(data.level, data.production),
            isMenuHeader = true
        },
        {
            header = "Upgrade Station",
            icon = 'fas fa-arrow-up',
            txt = "Cost: $" .. (Config.PowerStations.upgrades[data.level + 1] and Config.PowerStations.upgrades[data.level + 1].price or "MAX"),
            params = {
                event = "qb-WindPower:client:UpgradeStation",
                args = {
                    stationId = data.stationId,
                    level = data.level
                }
            },
            disabled = not Config.PowerStations.upgrades[data.level + 1]
        },
        {
            header = "Sell to Player",
            icon = 'fas fa-handshake',
            txt = "Sell station to another player",
            params = {
                event = "qb-WindPower:client:SellToPlayer",
                args = {
                    stationId = data.stationId,
                    level = data.level,
                    production = data.production
                }
            }
        },
        {
            header = "Sell Station (40% Refund)",
            icon = 'fas fa-dollar-sign',
            txt = ("Receive $%d"):format(Config.PowerStations.basePrice * 0.4),
            params = {
                event = "qb-WindPower:client:SellStation",
                args = {
                    stationId = data.stationId
                }
            }
        },
        {
            header = "Set GPS Location",
            icon = 'fas fa-location-dot',
            txt = "Mark station on map",
            params = {
                isAction = true,
                event = function()
                    SetNewWaypoint(data.coords.x, data.coords.y)
                    Notify('GPS set to Station #' .. data.stationId, 'success')
                end
            }
        },
        {
            header = "Collect Earnings",
            icon = 'fas fa-money-bill',
            txt = "Collect stored money from station",
            params = {
                event = "qb-WindPower:client:CollectMoney",
                args = {
                    stationId = data.stationId
                }
            }
        },
        {
            header = "Repair Station",
            icon = 'fas fa-wrench',
            txt = "Repair station condition",
            params = {
                event = "qb-WindPower:client:RepairStation",
                args = {
                    stationId = data.stationId
                }
            }
        },
        {
            header = "← Go Back",
            icon = 'fas fa-circle-left',
            txt = "",
            params = {
                event = "qb-WindPower:client:OpenManagerMenu"
            }
        }
    }

    OpenMenu(menuItems)
end)

RegisterNetEvent('qb-WindPower:client:CollectMoney')
AddEventHandler('qb-WindPower:client:CollectMoney', function(data)
    TriggerServerEvent('qb-WindPower:server:CollectMoney', data.stationId)
end)



RegisterNetEvent('qb-WindPower:client:RepairStation')
AddEventHandler('qb-WindPower:client:RepairStation', function(data)
    QBCore.Functions.TriggerCallback('qb-WindPower:server:GetRepairCost', function(repairCost, currentHealth)
        if Config.Menu == "ox" then
            lib.registerContext({
                id = 'repair_station',
                title = 'Repair Station',
                options = {
                    {
                        title = "Station Information",
                        description = ("Current Health: %d%%\nRepair Cost: $%d"):format(currentHealth, repairCost),
                        icon = 'fas fa-wrench',
                        disabled = true
                    },
                    {
                        title = currentHealth >= 100 and "No Repairs Needed" or "Confirm Repair",
                        description = currentHealth >= 100 and "Station is at full health" or "Pay repair cost and fix station",
                        icon = 'fas fa-check',
                        disabled = currentHealth >= 100,
                        onSelect = function()
                            if currentHealth < 100 then
                                TriggerServerEvent('qb-WindPower:server:RepairStation', data.stationId)
                            end
                        end
                    },
                    {
                        title = "Cancel",
                        description = "Cancel repair",
                        icon = 'fas fa-xmark',
                        onSelect = function()
                            -- Menu closes automatically
                        end
                    }
                }
            })
            lib.showContext('repair_station')
        else
            local menuItems = {
                {
                    header = "Repair Station",
                    txt = ("Current Health: %d%%\nRepair Cost: $%d"):format(currentHealth, repairCost),
                    icon = 'fas fa-wrench',
                    isMenuHeader = true
                },
                {
                    header = currentHealth >= 100 and "No Repairs Needed" or "Confirm Repair",
                    txt = currentHealth >= 100 and "Station is at full health" or "Pay repair cost and fix station",
                    icon = 'fas fa-check',
                    disabled = currentHealth >= 100,
                    params = {
                        isAction = true,
                        event = function()
                            if currentHealth < 100 then
                                TriggerServerEvent('qb-WindPower:server:RepairStation', data.stationId)
                            end
                        end
                    }
                },
                {
                    header = "Cancel",
                    txt = "Cancel repair",
                    icon = 'fas fa-xmark',
                    params = {
                        event = "qb-menu:closeMenu"
                    }
                }
            }
            exports['qb-menu']:openMenu(menuItems)
        end
    end, data.stationId)
end)



RegisterNetEvent('qb-WindPower:client:SellToPlayer')
AddEventHandler('qb-WindPower:client:SellToPlayer', function(data)
    local dialog = nil
    if Config.Menu == "ox" then
        dialog = lib.inputDialog('Sell Power Station', {
            {type = 'number', label = 'Player ID', description = 'Enter the player ID', required = true},
            {type = 'number', label = 'Price', description = 'Enter the selling price', required = true, min = 1}
        })
    else
        local input = exports['qb-input']:ShowInput({
            header = "Sell Power Station",
            submitText = "Confirm",
            inputs = {
                {
                    type = 'number',
                    name = 'playerid',
                    text = 'Player ID',
                    isRequired = true
                },
                {
                    type = 'number',
                    name = 'price',
                    text = 'Price',
                    isRequired = true
                }
            }
        })
        
        if input then
            dialog = {tonumber(input.playerid), tonumber(input.price)}
        end
    end

    if dialog then
        if dialog[1] and dialog[2] then
            local targetPed = GetPlayerPed(GetPlayerFromServerId(dialog[1]))
            if targetPed and #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed)) < 3.0 then
                TriggerServerEvent('qb-WindPower:server:RequestSale', dialog[1], dialog[2], data.stationId)
            else
                Notify('The buyer must be nearby!', 'error')
            end
        end
    end
end)


RegisterNetEvent('qb-WindPower:client:ShowConfirmBuy')
AddEventHandler('qb-WindPower:client:ShowConfirmBuy', function(sellerId, price, stationId)
    if Config.Menu == "ox" then
        lib.registerContext({
            id = 'confirm_station_purchase',
            title = 'Confirm Purchase',
            options = {
                {
                    title = "Purchase Power Station",
                    description = ("Price: $%d"):format(price),
                    icon = 'fas fa-bolt',
                    onSelect = function()
                        TriggerServerEvent('qb-WindPower:server:ConfirmPurchase', sellerId, price, stationId, true)
                    end
                },
                {
                    title = "Decline Purchase",
                    description = "Cancel the transaction",
                    icon = 'fas fa-xmark',
                    onSelect = function()
                        TriggerServerEvent('qb-WindPower:server:ConfirmPurchase', sellerId, price, stationId, false)
                    end
                }
            }
        })
        lib.showContext('confirm_station_purchase')
    else
        local menuItems = {
            {
                header = "Purchase Power Station",
                txt = ("Price: $%d"):format(price),
                icon = 'fas fa-bolt',
                params = {
                    isAction = true,
                    event = function()
                        TriggerServerEvent('qb-WindPower:server:ConfirmPurchase', sellerId, price, stationId, true)
                    end
                }
            },
            {
                header = "Decline Purchase",
                txt = "Cancel the transaction",
                icon = 'fas fa-xmark',
                params = {
                    isAction = true,
                    event = function()
                        TriggerServerEvent('qb-WindPower:server:ConfirmPurchase', sellerId, price, stationId, false)
                    end
                }
            }
        }
        exports['qb-menu']:openMenu(menuItems)
    end
end)


RegisterNetEvent('qb-WindPower:client:SellStation')
AddEventHandler('qb-WindPower:client:SellStation', function(data)
    local refundAmount = math.floor(Config.PowerStations.basePrice * 0.4)
    
    if Config.Menu == "ox" then
        local confirm = lib.alertDialog({
            header = 'Confirm Sale',
            content = string.format('Are you sure you want to sell this station?\nYou will receive: $%d (40%% refund)', refundAmount),
            cancel = true,
            labels = {
                confirm = 'Yes',
                cancel = 'No'
            }
        })
        if confirm == 'confirm' then
            TriggerServerEvent('qb-WindPower:server:SellStation', data.stationId)
        end
    else
        local menuItems = {
            {
                header = "Confirm Sale",
                txt = string.format("Refund Amount: $%d (40%%)", refundAmount),
                icon = 'fas fa-dollar-sign',
                params = {
                    isAction = true,
                    event = function()
                        TriggerServerEvent('qb-WindPower:server:SellStation', data.stationId)
                    end
                }
            },
            {
                header = "Cancel",
                txt = "Cancel the sale",
                icon = 'fas fa-xmark',
                params = {
                    event = "qb-menu:closeMenu"
                }
            }
        }
        exports['qb-menu']:openMenu(menuItems)
    end
end)


RegisterNetEvent('qb-WindPower:client:OpenManagerMenu')
AddEventHandler('qb-WindPower:client:OpenManagerMenu', function()
    TriggerEvent('qb-WindPower:client:ViewStations')
end)


local function GetHealthColor(health)
    if health > 70 then return "green"
    elseif health > 30 then return "yellow"
    else return "red" end
end


RegisterNetEvent('qb-WindPower:client:ViewStations')
AddEventHandler('qb-WindPower:client:ViewStations', function()
    QBCore.Functions.TriggerCallback('qb-WindPower:server:GetPlayerStations', function(stations)
        if #stations == 0 then
            Notify('You do not own any power stations!', 'error')
            return
        end

        local menuItems = {
            {
                header = "Power Station Management",
                icon = 'fas fa-industry',
                isMenuHeader = true
            }
        }

        for _, station in pairs(stations) do
            local coords = json.decode(station.location)
            local healthText = ("Health: %d%% "):format(station.health)
            menuItems[#menuItems + 1] = {
                header = "Station #" .. station.id,
                icon = 'fas fa-bolt',
                txt = ("Level: %d | Production: %d/hr\n%s"):format(station.level, station.production, healthText),
                params = {
                    event = "qb-WindPower:client:StationOptions",
                    args = {
                        stationId = station.id,
                        level = station.level,
                        production = station.production,
                        coords = coords
                    }
                }
            }
        end

        menuItems[#menuItems + 1] = {
            header = "Close",
            icon = 'fas fa-xmark',
            txt = "",
            params = {
                event = "qb-menu:closeMenu"
            }
        }

        OpenMenu(menuItems)
    end)
end)

RegisterNetEvent('qb-WindPower:client:ToggleAvailableStations')
AddEventHandler('qb-WindPower:client:ToggleAvailableStations', function()
    ToggleAvailableStations(not showingAvailable)
    Notify(showingAvailable and 'Showing available stations' or 'Hidden available stations', 'info')
end)
