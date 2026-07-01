local Config = {
    SelectorCamera = {
        coords = vector3(-75.29, -818.18, 326.18),
        rotation = vector3(-18.0, 0.0, 160.0),
        fov = 50.0
    },
    CreatorCoords = vector4(402.86, -996.64, -99.0, 180.0),
    DefaultSpawn = vector4(-1037.59, -2737.65, 20.17, 329.0)
}

local DefaultAppearance = {
    male = {
        model = 'mp_m_freemode_01',
        face = { mother = 21, father = 0, shapeMix = 0.5, skinMix = 0.5 },
        hair = { style = 0, color = 0, highlight = 0 },
        overlays = {
            beard = -1, beardOpacity = 0.0, beardColor = 0,
            eyebrows = 0, eyebrowsOpacity = 0.8, eyebrowsColor = 0,
            makeup = -1, makeupOpacity = 0.0
        },
        eyeColor = 0,
        components = {
            ['1'] = { drawable = 0, texture = 0 },
            ['3'] = { drawable = 15, texture = 0 },
            ['4'] = { drawable = 1, texture = 0 },
            ['5'] = { drawable = 0, texture = 0 },
            ['6'] = { drawable = 1, texture = 0 },
            ['7'] = { drawable = 0, texture = 0 },
            ['8'] = { drawable = 15, texture = 0 },
            ['9'] = { drawable = 0, texture = 0 },
            ['10'] = { drawable = 0, texture = 0 },
            ['11'] = { drawable = 0, texture = 0 }
        },
        props = {
            ['0'] = { drawable = -1, texture = 0 },
            ['1'] = { drawable = -1, texture = 0 },
            ['2'] = { drawable = -1, texture = 0 },
            ['3'] = { drawable = -1, texture = 0 },
            ['4'] = { drawable = -1, texture = 0 },
            ['5'] = { drawable = -1, texture = 0 },
            ['6'] = { drawable = -1, texture = 0 },
            ['7'] = { drawable = -1, texture = 0 }
        }
    },
    female = {
        model = 'mp_f_freemode_01',
        face = { mother = 21, father = 0, shapeMix = 0.5, skinMix = 0.5 },
        hair = { style = 0, color = 0, highlight = 0 },
        overlays = {
            beard = -1, beardOpacity = 0.0, beardColor = 0,
            eyebrows = 0, eyebrowsOpacity = 0.8, eyebrowsColor = 0,
            makeup = -1, makeupOpacity = 0.0
        },
        eyeColor = 0,
        components = {
            ['1'] = { drawable = 0, texture = 0 },
            ['3'] = { drawable = 15, texture = 0 },
            ['4'] = { drawable = 4, texture = 0 },
            ['5'] = { drawable = 0, texture = 0 },
            ['6'] = { drawable = 3, texture = 0 },
            ['7'] = { drawable = 0, texture = 0 },
            ['8'] = { drawable = 14, texture = 0 },
            ['9'] = { drawable = 0, texture = 0 },
            ['10'] = { drawable = 0, texture = 0 },
            ['11'] = { drawable = 5, texture = 0 }
        },
        props = {
            ['0'] = { drawable = -1, texture = 0 },
            ['1'] = { drawable = -1, texture = 0 },
            ['2'] = { drawable = -1, texture = 0 },
            ['3'] = { drawable = -1, texture = 0 },
            ['4'] = { drawable = -1, texture = 0 },
            ['5'] = { drawable = -1, texture = 0 },
            ['6'] = { drawable = -1, texture = 0 },
            ['7'] = { drawable = -1, texture = 0 }
        }
    }
}

local selectorCam = nil
local creatorCam = nil
local menuOpen = false
local creatorOpen = false
local currentSlot = nil
local currentCharacters = {}
local currentAppearance = nil
local currentGender = 'male'
local selectedCharacterId = nil
local pendingCallbacks = {}
local requestCounter = 0
local started = false

local function copyTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local copied = {}
    for key, item in pairs(value) do
        copied[key] = copyTable(item)
    end
    return copied
end

local function nuiFocus(focus, cursor)
    SetNuiFocus(focus, cursor)
    SetNuiFocusKeepInput(false)
end

local function serverCallback(name, payload, cb)
    requestCounter = requestCounter + 1
    local requestId = ('%s:%s'):format(GetGameTimer(), requestCounter)
    pendingCallbacks[requestId] = cb

    TriggerServerEvent(('n33s_creator:server:%s'):format(name), requestId, payload or {})

    SetTimeout(15000, function()
        if pendingCallbacks[requestId] then
            local callback = pendingCallbacks[requestId]
            pendingCallbacks[requestId] = nil
            callback({ ok = false, error = 'Serwer nie odpowiedział na czas.' })
        end
    end)
end

RegisterNetEvent('n33s_creator:client:serverResponse', function(requestId, payload)
    local callback = pendingCallbacks[requestId]
    if not callback then
        return
    end

    pendingCallbacks[requestId] = nil
    callback(payload or { ok = false, error = 'Pusta odpowiedź serwera.' })
end)

local function notify(message)
    TriggerEvent('chat:addMessage', {
        color = { 219, 87, 87 },
        args = { 'n33s_creator', message }
    })
end

RegisterNetEvent('n33s_creator:client:notify', notify)

local function destroyCamera(camera)
    if camera and DoesCamExist(camera) then
        DestroyCam(camera, false)
    end
end

local function stopCameras()
    destroyCamera(selectorCam)
    destroyCamera(creatorCam)
    selectorCam = nil
    creatorCam = nil
    RenderScriptCams(false, true, 700, true, true)
end

local function setupSelectorCamera()
    destroyCamera(creatorCam)
    creatorCam = nil

    if selectorCam and DoesCamExist(selectorCam) then
        DestroyCam(selectorCam, false)
    end

    selectorCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        Config.SelectorCamera.coords.x,
        Config.SelectorCamera.coords.y,
        Config.SelectorCamera.coords.z,
        Config.SelectorCamera.rotation.x,
        Config.SelectorCamera.rotation.y,
        Config.SelectorCamera.rotation.z,
        Config.SelectorCamera.fov,
        false,
        0
    )

    SetCamActive(selectorCam, true)
    RenderScriptCams(true, true, 1200, true, true)
end

local function loadModel(modelName)
    local model = GetHashKey(modelName)
    if not IsModelInCdimage(model) or not IsModelValid(model) then
        return false
    end

    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        Wait(0)
        if GetGameTimer() > deadline then
            return false
        end
    end

    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    return true
end

local ClothingComponentIds = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local LimitComponentIds = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PropIds = { 0, 1, 2, 3, 4, 5, 6, 7 }

local function setComponentSafe(ped, component, drawable, texture)
    local drawableCount = GetNumberOfPedDrawableVariations(ped, component)
    drawable = math.floor(tonumber(drawable) or 0)
    texture = math.floor(tonumber(texture) or 0)

    if drawableCount and drawableCount > 0 then
        drawable = math.max(0, math.min(drawable, drawableCount - 1))
    else
        drawable = 0
    end

    local textureCount = GetNumberOfPedTextureVariations(ped, component, drawable)
    if textureCount and textureCount > 0 then
        texture = math.max(0, math.min(texture, textureCount - 1))
    else
        texture = 0
    end

    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function setPropSafe(ped, prop, drawable, texture)
    local drawableCount = GetNumberOfPedPropDrawableVariations(ped, prop)
    drawable = math.floor(tonumber(drawable) or -1)
    texture = math.floor(tonumber(texture) or 0)

    if drawable < 0 or not drawableCount or drawableCount <= 0 then
        ClearPedProp(ped, prop)
        return
    end

    drawable = math.max(0, math.min(drawable, drawableCount - 1))

    local textureCount = GetNumberOfPedPropTextureVariations(ped, prop, drawable)
    if textureCount and textureCount > 0 then
        texture = math.max(0, math.min(texture, textureCount - 1))
    else
        texture = 0
    end

    SetPedPropIndex(ped, prop, drawable, texture, true)
end

local function getCreatorLimits()
    local ped = PlayerPedId()
    local limits = { components = {}, props = {} }

    if not DoesEntityExist(ped) then
        return limits
    end

    for _, component in ipairs(LimitComponentIds) do
        local drawable = GetPedDrawableVariation(ped, component)
        local drawableCount = tonumber(GetNumberOfPedDrawableVariations(ped, component)) or 0
        local textureCount = tonumber(GetNumberOfPedTextureVariations(ped, component, drawable)) or 0

        limits.components[tostring(component)] = {
            drawableMax = math.max(drawableCount - 1, 0),
            textureMax = math.max(textureCount - 1, 0)
        }
    end

    for _, prop in ipairs(PropIds) do
        local drawable = GetPedPropIndex(ped, prop)
        local drawableCount = tonumber(GetNumberOfPedPropDrawableVariations(ped, prop)) or 0
        local textureCount = 0

        if drawable and drawable >= 0 then
            textureCount = tonumber(GetNumberOfPedPropTextureVariations(ped, prop, drawable)) or 0
        end

        limits.props[tostring(prop)] = {
            drawableMax = math.max(drawableCount - 1, -1),
            textureMax = math.max(textureCount - 1, 0)
        }
    end

    return limits
end

local function sendCreatorLimits()
    if creatorOpen then
        SendNUIMessage({ action = 'creatorLimits', limits = getCreatorLimits() })
    end
end

local function setOverlaySafe(ped, overlay, index, opacity, colorType, color)
    index = math.floor(tonumber(index) or -1)
    opacity = tonumber(opacity) or 0.0

    if index < 0 then
        SetPedHeadOverlay(ped, overlay, 255, 0.0)
        return
    end

    local maxValues = GetNumHeadOverlayValues(overlay)
    if maxValues and maxValues > 0 then
        index = math.min(index, maxValues - 1)
    end

    SetPedHeadOverlay(ped, overlay, index, math.max(0.0, math.min(opacity, 1.0)))

    if color ~= nil then
        color = math.max(0, math.min(math.floor(tonumber(color) or 0), 63))
        SetPedHeadOverlayColor(ped, overlay, colorType or 1, color, color)
    end
end

local function applyAppearance(appearance)
    if type(appearance) ~= 'table' then
        appearance = DefaultAppearance[currentGender]
    end

    currentAppearance = copyTable(appearance)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local face = appearance.face or {}
    SetPedHeadBlendData(
        ped,
        tonumber(face.mother) or 21,
        tonumber(face.father) or 0,
        0,
        tonumber(face.mother) or 21,
        tonumber(face.father) or 0,
        0,
        tonumber(face.shapeMix) or 0.5,
        tonumber(face.skinMix) or 0.5,
        0.0,
        false
    )

    local hair = appearance.hair or {}
    setComponentSafe(ped, 2, hair.style, 0)
    SetPedHairColor(
        ped,
        math.floor(tonumber(hair.color) or 0),
        math.floor(tonumber(hair.highlight) or 0)
    )

    local overlays = appearance.overlays or {}
    setOverlaySafe(ped, 1, overlays.beard, overlays.beardOpacity, 1, overlays.beardColor)
    setOverlaySafe(ped, 2, overlays.eyebrows, overlays.eyebrowsOpacity, 1, overlays.eyebrowsColor)
    setOverlaySafe(ped, 4, overlays.makeup, overlays.makeupOpacity, 2, 0)

    SetPedEyeColor(ped, math.floor(tonumber(appearance.eyeColor) or 0))

    local components = type(appearance.components) == 'table' and appearance.components or {}
    local clothes = type(appearance.clothes) == 'table' and appearance.clothes or nil

    if clothes and not next(components) then
        components = {
            ['4'] = { drawable = clothes.legs, texture = clothes.legsTexture },
            ['6'] = { drawable = clothes.shoes, texture = clothes.shoesTexture },
            ['8'] = { drawable = clothes.tshirt, texture = clothes.tshirtTexture },
            ['11'] = { drawable = clothes.torso, texture = clothes.torsoTexture }
        }
    end

    for _, component in ipairs(ClothingComponentIds) do
        local item = components[tostring(component)] or components[component] or {}
        setComponentSafe(ped, component, item.drawable, item.texture)
    end

    local props = type(appearance.props) == 'table' and appearance.props or {}
    for _, prop in ipairs(PropIds) do
        local item = props[tostring(prop)] or props[prop] or {}
        setPropSafe(ped, prop, item.drawable, item.texture)
    end

    sendCreatorLimits()
end

local function preparePedForMenu()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    ClearPedTasksImmediately(ped)
    DisplayRadar(false)
    DisplayHud(false)
end

local function placePedInCreator()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(Config.CreatorCoords.x, Config.CreatorCoords.y, Config.CreatorCoords.z)
    SetEntityCoordsNoOffset(ped, Config.CreatorCoords.x, Config.CreatorCoords.y, Config.CreatorCoords.z, false, false, false)
    SetEntityHeading(ped, Config.CreatorCoords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    ClearPedTasksImmediately(ped)
end

local function setupCreatorCamera(mode)
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then
        return
    end

    local cameraModes = {
        face = { offset = vector3(0.0, 0.72, 0.66), target = 0.66, fov = 30.0 },
        body = { offset = vector3(0.0, 1.55, 0.28), target = 0.25, fov = 45.0 },
        full = { offset = vector3(0.0, 2.35, 0.52), target = 0.35, fov = 50.0 },
        shoes = { offset = vector3(0.0, 1.0, -0.55), target = -0.78, fov = 28.0 }
    }

    local selected = cameraModes[mode] or cameraModes.body
    local camCoords = GetOffsetFromEntityInWorldCoords(ped, selected.offset.x, selected.offset.y, selected.offset.z)
    local targetCoords = GetEntityCoords(ped)

    if not creatorCam or not DoesCamExist(creatorCam) then
        creatorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    end

    SetCamCoord(creatorCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamFov(creatorCam, selected.fov)
    PointCamAtCoord(creatorCam, targetCoords.x, targetCoords.y, targetCoords.z + selected.target)
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, 550, true, true)
end

local function setCreatorGender(gender, appearance)
    currentGender = gender == 'female' and 'female' or 'male'

    if not loadModel(DefaultAppearance[currentGender].model) then
        notify('Nie udało się wczytać modelu postaci.')
        return
    end

    placePedInCreator()
    SetPedDefaultComponentVariation(PlayerPedId())
    applyAppearance(appearance or DefaultAppearance[currentGender])
    setupCreatorCamera('body')
    sendCreatorLimits()
end

local function beginCreator(slot)
    currentSlot = slot
    menuOpen = false
    creatorOpen = true
    DoScreenFadeOut(250)
    Wait(300)
    destroyCamera(selectorCam)
    selectorCam = nil
    setCreatorGender('male', DefaultAppearance.male)
    DoScreenFadeIn(350)
end

local function openSelector()
    menuOpen = true
    creatorOpen = false
    selectedCharacterId = nil
    currentSlot = nil

    DoScreenFadeOut(500)
    Wait(550)
    preparePedForMenu()
    setupSelectorCamera()
    nuiFocus(true, true)

    serverCallback('loadCharacters', {}, function(response)
        if not response.ok then
            notify(response.error or 'Nie udało się pobrać postaci.')
            response.characters = {}
            response.maxCharacters = 3
        end

        currentCharacters = response.characters or {}
        SendNUIMessage({
            action = 'openSelector',
            characters = currentCharacters,
            maxCharacters = response.maxCharacters or 3
        })

        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        DoScreenFadeIn(650)
    end)
end

local function spawnCharacter(spawn)
    local coords = spawn and spawn.coords or {}
    local skin = spawn and spawn.skin or DefaultAppearance.male
    local gender = spawn and spawn.gender == 'female' and 'female' or 'male'

    coords.x = tonumber(coords.x) or Config.DefaultSpawn.x
    coords.y = tonumber(coords.y) or Config.DefaultSpawn.y
    coords.z = tonumber(coords.z) or Config.DefaultSpawn.z
    coords.h = tonumber(coords.h or coords.heading) or Config.DefaultSpawn.w

    DoScreenFadeOut(500)
    Wait(550)

    menuOpen = false
    creatorOpen = false
    nuiFocus(false, false)
    SendNUIMessage({ action = 'closeAll' })
    stopCameras()

    loadModel(gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01')

    local ped = PlayerPedId()
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, coords.h, true, true, false)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.h)
    SetPedDefaultComponentVariation(ped)
    applyAppearance(skin)
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    DisplayRadar(true)
    DisplayHud(true)

    Wait(250)
    DoScreenFadeIn(800)
end

RegisterNUICallback('openCreator', function(data, cb)
    local slot = tonumber(data and data.slot)
    if not slot or slot < 1 or slot > 3 then
        cb({ ok = false, error = 'Nieprawidłowy slot.' })
        return
    end

    beginCreator(slot)
    cb({ ok = true })
end)

RegisterNUICallback('backToSelection', function(_, cb)
    creatorOpen = false
    menuOpen = true
    DoScreenFadeOut(250)
    Wait(300)
    preparePedForMenu()
    setupSelectorCamera()
    SendNUIMessage({
        action = 'openSelector',
        characters = currentCharacters,
        maxCharacters = 3
    })
    DoScreenFadeIn(350)
    cb({ ok = true })
end)

RegisterNUICallback('changeGender', function(data, cb)
    local gender = data and data.gender == 'female' and 'female' or 'male'
    local appearance = data and data.skin or DefaultAppearance[gender]
    setCreatorGender(gender, appearance)
    cb({ ok = true })
end)

RegisterNUICallback('updateAppearance', function(data, cb)
    if creatorOpen and type(data) == 'table' then
        applyAppearance(data.skin or data)
    end
    cb({ ok = true })
end)

RegisterNUICallback('requestCreatorLimits', function(_, cb)
    sendCreatorLimits()
    cb({ ok = true })
end)

RegisterNUICallback('cameraMode', function(data, cb)
    if creatorOpen then
        setupCreatorCamera(data and data.mode or 'body')
    end
    cb({ ok = true })
end)

RegisterNUICallback('rotatePed', function(data, cb)
    if creatorOpen then
        local ped = PlayerPedId()
        local delta = tonumber(data and data.delta) or 0.0
        SetEntityHeading(ped, GetEntityHeading(ped) + delta)
    end
    cb({ ok = true })
end)

RegisterNUICallback('playCharacter', function(data, cb)
    serverCallback('playCharacter', { id = data and data.id }, function(response)
        if response.ok then
            selectedCharacterId = response.character and response.character.id or nil
            spawnCharacter(response.spawn)
        end
        cb(response)
    end)
end)

RegisterNUICallback('createCharacter', function(data, cb)
    local payload = data or {}
    payload.slot = currentSlot

    serverCallback('createCharacter', payload, function(response)
        if response.ok then
            selectedCharacterId = response.character and response.character.id or nil
            spawnCharacter(response.spawn)
        end
        cb(response)
    end)
end)

RegisterNUICallback('closeIdCard', function(_, cb)
    SendNUIMessage({ action = 'hideIdCard' })
    if not menuOpen and not creatorOpen then
        nuiFocus(false, false)
    end
    cb({ ok = true })
end)

RegisterCommand('dowod', function()
    TriggerServerEvent('n33s_creator:server:requestIdCard')
end, false)

RegisterNetEvent('n33s_creator:client:showIdCard', function(card)
    SendNUIMessage({ action = 'showIdCard', card = card })
    nuiFocus(true, true)
end)

CreateThread(function()
    while true do
        if menuOpen or creatorOpen then
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(60000)
        if selectedCharacterId and not menuOpen and not creatorOpen then
            TriggerServerEvent('n33s_creator:server:saveCoords')
        end
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or started then
        return
    end

    started = true

    CreateThread(function()
        while not NetworkIsSessionStarted() do
            Wait(250)
        end

        while not DoesEntityExist(PlayerPedId()) do
            Wait(250)
        end

        Wait(1000)
        openSelector()
    end)
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if selectedCharacterId then
        TriggerServerEvent('n33s_creator:server:saveCoords')
    end

    stopCameras()
    nuiFocus(false, false)
    DisplayRadar(true)
    DisplayHud(true)
end)
