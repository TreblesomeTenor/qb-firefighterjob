local QBCore = exports['qb-core']:GetCoreObject()

local PlayerJob = {}
local onDuty = false
local currentGarage = 1

local FireJobName = Config.FireJobName or 'fire'
local FireJobNames = Config.FireJobNames or { 'fire', 'firefighter', 'police', 'ambulance' }
local targetZonesCreated = false

-- Functions

local function RefreshPlayerJob()
    local PlayerData = QBCore.Functions.GetPlayerData()

    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job
        onDuty = PlayerData.job.onduty or false
    end
end

local function IsFireJob()
    RefreshPlayerJob()

    if not PlayerJob or not PlayerJob.name then
        return false
    end

    if PlayerJob.name == FireJobName then
        return true
    end

    for _, jobName in pairs(FireJobNames) do
        if PlayerJob.name == jobName then
            return true
        end
    end

    return false
end

local function IsFireOnDuty()
    RefreshPlayerJob()
    return IsFireJob() and onDuty
end

local function Notify(message, notifyType)
    QBCore.Functions.Notify(message, notifyType or 'primary')
end

local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

local function GetClosestPlayer()
    local closestPlayers = QBCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function TakeOutVehicle(vehicleInfo)
    local coords = Config.Locations['vehicle'][currentGarage]

    QBCore.Functions.SpawnVehicle(vehicleInfo, function(veh)
        SetVehicleNumberPlateText(veh, 'FIRE' .. tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        exports['LegacyFuel']:SetFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

        if Config.VehicleSettings[vehicleInfo] ~= nil then
            QBCore.Shared.SetDefaultVehicleExtras(veh, Config.VehicleSettings[vehicleInfo].extras)
        end

        -- London Studios Fire Supply Line v2
        if GetResourceState('Supply-Line') == 'started' then
            local maxWater = exports['Supply-Line']:GetVehicleMaxWaterLevel(veh)

            if maxWater and maxWater > 0 then
                local waterAmount = maxWater * 0.80
                local foamAmount = maxWater * 0.20

                exports['Supply-Line']:SetVehicleWaterLevel(
                    veh,
                    waterAmount,
                    foamAmount,
                    true
                )
            end
        end

        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, coords, true)
end

function MenuGarage()
    local vehicleMenu = {
        {
            header = 'Fire Vehicles',
            isMenuHeader = true
        }
    }

    local PlayerData = QBCore.Functions.GetPlayerData()
    local grade = PlayerData.job and PlayerData.job.grade and PlayerData.job.grade.level or 0
    local authorizedVehicles = Config.AuthorizedVehicles[grade] or {}

    for veh, label in pairs(authorizedVehicles) do
        vehicleMenu[#vehicleMenu + 1] = {
            header = label,
            txt = '',
            params = {
                event = 'firefighter:client:TakeOutVehicle',
                args = {
                    vehicle = veh
                }
            }
        }
    end

    vehicleMenu[#vehicleMenu + 1] = {
        header = '⬅ Close Menu',
        txt = '',
        params = {
            event = 'qb-menu:client:closeMenu'
        }
    }

    exports['qb-menu']:openMenu(vehicleMenu)
end

local function ToggleDuty()
    onDuty = not onDuty
    TriggerServerEvent('QBCore:ToggleDuty')
end

local function StoreCurrentVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)

    if veh ~= 0 then
        QBCore.Functions.DeleteVehicle(veh)
    end
end

local function OpenVehicleMenu(garageIndex)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        StoreCurrentVehicle()
        return
    end

    currentGarage = garageIndex
    MenuGarage()
end

local function TakeOutHelicopter(heliIndex)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        StoreCurrentVehicle()
        return
    end

    local coords = Config.Locations['helicopter'][heliIndex]

    QBCore.Functions.SpawnVehicle(Config.Helicopter, function(veh)
        SetVehicleNumberPlateText(veh, 'LIFE' .. tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, coords.w)
        SetVehicleLivery(veh, 1) -- Firefighter Livery
        exports['LegacyFuel']:SetFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(ped, veh, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
    end, coords, true)
end

local function CreateFirefighterTargets()
    if targetZonesCreated then return end
    targetZonesCreated = true

    if Config.Locations['stash'] then
        for k, v in pairs(Config.Locations['stash']) do
            exports.ox_target:addSphereZone({
                coords = v,
                radius = 2.5,
                debug = Config.DebugTargets or false,
                options = {
                    {
                        name = ('firefighter_stash_%s'):format(k),
                        icon = 'fa-solid fa-box-archive',
                        label = 'Open Personal Stash',
                        canInteract = function()
                            return IsFireOnDuty()
                        end,
                        onSelect = function()
                            TriggerServerEvent('firefighter:server:OpenPersonalStash')
                        end
                    }
                }
            })
        end
    end

    if Config.Locations['duty'] then
        for k, v in pairs(Config.Locations['duty']) do
            exports.ox_target:addSphereZone({
                coords = v,
                radius = 2.5,
                debug = Config.DebugTargets or false,
                options = {
                    {
                        name = ('firefighter_duty_%s'):format(k),
                        icon = 'fa-solid fa-clipboard-check',
                        label = 'Toggle Duty',
                        canInteract = function()
                            return IsFireJob()
                        end,
                        onSelect = function()
                            ToggleDuty()
                        end
                    }
                }
            })
        end
    end

    if Config.Locations['armory'] then
        for k, v in pairs(Config.Locations['armory']) do
            exports.ox_target:addSphereZone({
                coords = v,
                radius = 2.5,
                debug = Config.DebugTargets or false,
                options = {
                    {
                        name = ('firefighter_armory_%s'):format(k),
                        icon = 'fa-solid fa-toolbox',
                        label = 'Open Armory',
                        canInteract = function()
                            return IsFireOnDuty()
                        end,
                        onSelect = function()
                            exports.ox_inventory:openInventory('shop', { type = 'fire_armory', id = 1 })
                        end
                    }
                }
            })
        end
    end

    if Config.Locations['vehicle'] then
        for k, v in pairs(Config.Locations['vehicle']) do
            local coords = vector3(v.x, v.y, v.z)

            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 3.0,
                debug = Config.DebugTargets or false,
                options = {
                    {
                        name = ('firefighter_vehicle_%s'):format(k),
                        icon = 'fa-solid fa-truck',
                        label = 'Vehicles / Store Vehicle',
                        canInteract = function()
                            return IsFireJob()
                        end,
                        onSelect = function()
                            OpenVehicleMenu(k)
                        end
                    }
                }
            })
        end
    end

    if Config.Locations['helicopter'] then
        for k, v in pairs(Config.Locations['helicopter']) do
            local coords = vector3(v.x, v.y, v.z)

            exports.ox_target:addSphereZone({
                coords = coords,
                radius = 3.5,
                debug = Config.DebugTargets or false,
                options = {
                    {
                        name = ('firefighter_heli_%s'):format(k),
                        icon = 'fa-solid fa-helicopter',
                        label = 'Helicopter / Store Helicopter',
                        canInteract = function()
                            return IsFireOnDuty()
                        end,
                        onSelect = function()
                            TakeOutHelicopter(k)
                        end
                    }
                }
            })
        end
    end
end

-- Events

RegisterNetEvent('firefighter:client:TakeOutVehicle', function(data)
    local vehicle = data.vehicle
    TakeOutVehicle(vehicle)
end)

RegisterNetEvent('firefighter:client:OpenPersonalStash', function(stashId)
    exports.ox_inventory:openInventory('stash', stashId)
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerJob = JobInfo
    TriggerServerEvent('ambulance:server:SetFirefighter')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    exports.spawnmanager:setAutoSpawn(false)

    local ped = PlayerPedId()
    local player = PlayerId()

    TriggerServerEvent('ambulance:server:SetFirefighter')

    CreateThread(function()
        Wait(5000)
        SetEntityMaxHealth(ped, 200)
        SetEntityHealth(ped, 200)
        SetPlayerHealthRechargeMultiplier(player, 0.0)
        SetPlayerHealthRechargeLimit(player, 0.0)
    end)

    CreateThread(function()
        Wait(1000)
        QBCore.Functions.GetPlayerData(function(PlayerData)
            PlayerJob = PlayerData.job
            onDuty = PlayerData.job.onduty
            SetPedArmour(ped, PlayerData.metadata['armor'])

            if (not PlayerData.metadata['inlaststand'] and PlayerData.metadata['isdead']) then
                deathTime = Laststand.ReviveInterval
                OnDeath()
                DeathTimer()
            elseif (PlayerData.metadata['inlaststand'] and not PlayerData.metadata['isdead']) then
                SetLaststand(true, true)
            else
                TriggerServerEvent('hospital:server:SetDeathStatus', false)
                TriggerServerEvent('hospital:server:SetLaststandStatus', false)
            end
        end)
    end)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    onDuty = duty
    TriggerServerEvent('ambulance:server:SetFirefighter')
end)

-- Threads

CreateThread(function()
    Wait(1000)

    local PlayerData = QBCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.job then
        PlayerJob = PlayerData.job
        onDuty = PlayerData.job.onduty
    end

    CreateFirefighterTargets()
end)


AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    Wait(1500)
    RefreshPlayerJob()
    CreateFirefighterTargets()
end)
