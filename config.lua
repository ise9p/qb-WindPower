Config = {}

Config.Managers = { -- Ped information
    {
        location = vector4(2136.88, 1936.2, 93.93, 75.25),
        model = "a_m_y_business_03",
        name = "voltage_seller_1"
    },
    {
        location = vector4(2100.98, 2342.4, 94.29, 180.41),
        model = "a_m_y_business_03",
        name = "voltage_seller_2"
    },
    {
        location = vector4(2461.54, 1481.76, 36.2, 188.51),
        model = "a_m_y_business_03",
        name = "voltage_seller_3"
    },
    {
        location = vector4(2302.48, 1721.72, 68.04, 93.53),
        model = "a_m_y_business_03",
        name = "voltage_seller_4"
    }
}

Config.Blips = {
    Ped = {
        sprite = 769,
        color = 0,
        scale = 0.6,
        label = "Power Station Manager"
    },
    PowerStation = {
        sprite = 767,
        color = 3,
        scale = 0.6,
        label = "Power Station"
    },
    Available = {
        sprite = 354,
        color = 0, -- Green
        scale = 0.7,
        label = "Available Power Station"
    }
}

Config.PowerStations = {
    basePrice = 50000, -- base price of a power station
    maxStations = 3, -- maximum number of power stations a player can own
    maxUpgrades = 3, -- maximum number of upgrades a power station can have
    moneyInterval = 15, -- minutes between earnings
    locations = {
        {coords = vector3(2132.5254, 1988.8330, 94.6575), price = 50000},
        {coords = vector3(2169.0801, 1933.7817, 97.1856), price = 50000},
        {coords = vector3(2191.8770, 1873.9202, 100.7368), price = 50000},
        {coords = vector3(2239.8218, 1830.2390, 107.6655), price = 50000},
        {coords = vector3(2184.7163, 1788.6201, 106.0629), price = 50000},
        {coords = vector3(2078.6670, 1688.8350, 101.6159), price = 50000},
        {coords = vector3(2265.4109, 1916.2590, 121.7958), price = 50000},
        {coords = vector3(2309.3352, 1970.3821, 129.8315), price = 50000},
        {coords = vector3(2271.0840, 1993.5759, 130.6666), price = 50000},
        {coords = vector3(2285.9360, 2076.7749, 121.3884), price = 50000},
        {coords = vector3(2329.5830, 2052.4465, 102.4181), price = 50000},
        {coords = vector3(2329.7930, 2116.4500, 106.7887), price = 50000},
        {coords = vector3(2346.6260, 2235.2148, 97.8168), price = 50000},
        {coords = vector3(2362.1208, 2289.5630, 92.7527), price = 50000},
        {coords = vector3(2424.9868, 1990.9088, 83.0958), price = 50000},
        {coords = vector3(2155.1638, 2334.5745, 108.4009), price = 50000},
        {coords = vector3(2166.1519, 2264.8828, 105.0851), price = 50000},
        {coords = vector3(2068.6836, 2357.0237, 95.5028), price = 50000},
        {coords = vector3(2096.7637, 2494.4207, 89.3041), price = 50000},
        {coords = vector3(2066.4016, 2275.1262, 91.8198), price = 50000},
        {coords = vector3(1974.7871, 2268.9395, 91.7940), price = 50000},
        {coords = vector3(2090.4976, 2153.4685, 108.7220), price = 50000},
        {coords = vector3(2123.5183, 2235.7371, 104.5293), price = 50000},
        {coords = vector3(1960.2076, 2070.0083, 83.2339), price = 50000},
        {coords = vector3(2052.5315, 2000.0190, 84.7961), price = 50000},
        {coords = vector3(2059.9448, 1893.7891, 91.5142), price = 50000},
        {coords = vector3(2120.2134, 1870.9663, 93.2386), price = 50000},
        {coords = vector3(2027.0967, 1840.7548, 94.2498), price = 50000},
        {coords = vector3(2355.9353, 1838.7291, 100.8372), price = 50000},
        {coords = vector3(2203.4731, 1649.9617, 82.2281), price = 50000},
        {coords = vector3(2207.5166, 1401.5569, 80.0360), price = 50000},
        {coords = vector3(2239.3518, 1530.8340, 73.0296), price = 50000},
        {coords = vector3(2317.8733, 1330.3899, 68.2965), price = 50000},
        {coords = vector3(2321.0552, 1449.8933, 61.7399), price = 50000},
        {coords = vector3(2359.9922, 1670.9192, 47.1798), price = 50000},
        {coords = vector3(2359.2654, 1509.8073, 52.8244), price = 50000},
        {coords = vector3(2360.2351, 1393.3003, 57.2665), price = 50000},
        {coords = vector3(2395.4780, 1272.1001, 60.6865), price = 50000},
        {coords = vector3(2405.1167, 1423.2506, 45.0455), price = 50000},
        {coords = vector3(2179.1257, 2167.5012, 115.8089), price = 50000}
    },
    upgrades = {
        [1] = {price = 25000, production = 100, earnings = 2}, -- Upgrade 1
        [2] = {price = 50000, production = 200, earnings = 4}, -- Upgrade 2
        [3] = {price = 100000, production = 300, earnings = 6}, -- Upgrade 3
    },
    healthDecay = {
        interval = 25, -- minutes between health decay
        amount = {min = 2, max = 5} -- random amount between these values
    },
    battery = {
        item = 'station_battery', -- Item name for the battery
        restore = 25, -- How much battery % each item restores
        drain = {
            interval = 10, -- minutes between battery drain
            amount = 2 -- % drained per interval
        },
        production = { -- Production modifiers based on battery level
            low = 0.25, -- Below 25% battery
            medium = 0.5, -- Below 50% battery
            high = 0.75, -- Below 75% battery
            full = 1.0 -- Above 75% battery
        }
    }
}

Config.Notify = "ox" -- "qb" for QBCore notifications, "ox" for ox_lib notifications
Config.Menu = "ox" -- "qb" for qb-menu, "ox" for ox_lib menu
Config.Target = "ox" -- "qb" for qb-target, "ox" for ox_target

Config.WeatherImpact = { -- Weather impact on production
    enabled = true, -- Enable or disable weather impact
    badWeather = { -- Weather types that affect production
        ['FOGGY'] = true, 
        ['OVERCAST'] = true, 
        ['CLOUDS'] = true, 
        ['RAIN'] = true,
        ['THUNDER'] = true, 
        ['RAIN'] = true,
        ['CLEARING'] = true
    },
    productionModifier = 1.0 -- 50% efficiency in bad weather
}

Config.Webhooks = {
    enabled = true,
    url = "", -- Discord webhook URL
    color = 3447003, -- Blue color
    footer = "QB-Voltage Logs",
    events = {
        purchase = true,
        repair = true,
        upgrade = true,
        weather = true,
        collect = true
    }
}

