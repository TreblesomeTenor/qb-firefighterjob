local QBCore = exports['qb-core']:GetCoreObject()

local FireJobName = Config.FireJobName or 'fire'
local personalStashes = {}
local armoryRegistered = false

-- Events

-- RegisterNetEvent('hospital:server:ambulanceAlert', function(text)
--     local src = source
--     local ped = GetPlayerPed(src)
--     local coords = GetEntityCoords(ped)
--     local players = QBCore.Functions.GetQBPlayers()
--     for k,v in pairs(players) do
--         if v.PlayerData.job.name == 'firefighter' and v.PlayerData.job.onduty then
--             TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, text)
--         end
--     end
-- end)

-- Callbacks

-- Commands

-- QBCore.Commands.Add('911f', 'Fire Report', {{name='message', help='Message to be sent'}}, false, function(source, args)
-- 	local src = source
-- 	if args[1] then message = table.concat(args, ' ') else message = 'Civilian Call' end
--     local ped = GetPlayerPed(src)
--     local coords = GetEntityCoords(ped)
--     local players = QBCore.Functions.GetQBPlayers()
--     for k,v in pairs(players) do
--         if v.PlayerData.job.name == 'firefighter' or v.PlayerData.job.name == 'police' and v.PlayerData.job.onduty then
--             TriggerClientEvent('hospital:client:ambulanceAlert', v.PlayerData.source, coords, message)
--         end
--     end
-- end)

-- Items

local function IsFirefighter(Player)
    return Player
        and Player.PlayerData
        and Player.PlayerData.job
        and Player.PlayerData.job.name == FireJobName
end

local function IsFirefighterOnDuty(Player)
    return IsFirefighter(Player) and Player.PlayerData.job.onduty
end

local function ConvertQBItemsToOxInventory(qbItems)
    local oxItems = {}

    if type(qbItems) ~= 'table' then
        return oxItems
    end

    -- Supports normal qb-inventory shop tables:
    -- Config.Items = { label = 'Armory', slots = 10, items = { [1] = { name = 'bandage', price = 0, amount = 50 } } }
    local sourceItems = qbItems.items or qbItems

    for _, item in pairs(sourceItems) do
        if type(item) == 'table' and item.name then
            oxItems[#oxItems + 1] = {
                name = item.name,
                price = item.price or 0,
                count = item.amount or item.count or 1,
                metadata = item.info or item.metadata
            }
        end
    end

    return oxItems
end

local function RegisterFireArmory()
    if armoryRegistered then return end
    armoryRegistered = true

    exports.ox_inventory:RegisterShop('fire_armory', {
        name = 'Fire Armory',
        inventory = ConvertQBItemsToOxInventory(Config.Items),
        groups = {
            [FireJobName] = 0
        }
    })
end

local function RegisterPersonalStash(Player)
    local citizenid = Player.PlayerData.citizenid
    local stashId = ('firefighterstash_%s'):format(citizenid)

    if personalStashes[stashId] then
        return stashId
    end

    exports.ox_inventory:RegisterStash(
        stashId,
        'Firefighter Personal Stash',
        Config.PersonalStashSlots or 50,
        Config.PersonalStashWeight or 100000,
        false,
        {
            [FireJobName] = 0
        }
    )

    personalStashes[stashId] = true
    return stashId
end

RegisterNetEvent('firefighter:server:OpenPersonalStash', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not IsFirefighterOnDuty(Player) then
        TriggerClientEvent('QBCore:Notify', src, 'You must be on-duty fire to use this stash.', 'error')
        return
    end

    local stashId = RegisterPersonalStash(Player)
    TriggerClientEvent('firefighter:client:OpenPersonalStash', src, stashId)
end)

CreateThread(function()
    Wait(1000)
    RegisterFireArmory()
end)
