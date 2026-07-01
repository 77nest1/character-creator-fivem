local Config = {
    MaxCharacters = 3,
    DefaultCoords = { x = -1037.59, y = -2737.65, z = 20.17, h = 329.0 },
    MinHeight = 150,
    MaxHeight = 200
}

local ActiveCharacters = {}
local CreatingPlayers = {}
local LastIdCardRequest = {}
local DatabaseReady = false

local CreateCharactersTableSql = [[
CREATE TABLE IF NOT EXISTS `characters` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `identifier` VARCHAR(64) NOT NULL,
    `slot` TINYINT UNSIGNED NOT NULL,
    `firstname` VARCHAR(32) NOT NULL,
    `lastname` VARCHAR(32) NOT NULL,
    `nationality` VARCHAR(48) NOT NULL DEFAULT 'Nieznane',
    `dateofbirth` VARCHAR(10) NOT NULL,
    `height` SMALLINT UNSIGNED NOT NULL,
    `gender` ENUM('male', 'female') NOT NULL,
    `skin` LONGTEXT NOT NULL,
    `coords` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uniq_characters_identifier_slot` (`identifier`, `slot`),
    KEY `idx_characters_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
]]

local DefaultSkin = {
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

local function ensureDatabase()
    if DatabaseReady then
        return true
    end

    local ok, err = pcall(function()
        MySQL.query.await(CreateCharactersTableSql)
    end)

    if not ok then
        print(('[n33s_creator] database init error: %s'):format(err))
        return false
    end

    DatabaseReady = true
    return true
end

CreateThread(function()
    if ensureDatabase() then
        print('[n33s_creator] tabela characters jest gotowa.')
    end
end)

local function respond(source, requestId, payload)
    TriggerClientEvent('n33s_creator:client:serverResponse', source, requestId, payload)
end

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

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
end

local function clampNumber(value, min, max, integer)
    local number = tonumber(value)
    if not number or number ~= number then
        number = min
    end

    if number < min then
        number = min
    elseif number > max then
        number = max
    end

    if integer then
        number = math.floor(number + 0.5)
    end

    return number
end

local function roundTwo(value)
    return math.floor((tonumber(value) or 0.0) * 100 + 0.5) / 100
end

local function sanitizeText(value, minLength, maxLength, label)
    if type(value) ~= 'string' then
        return nil, ('Pole %s jest nieprawidłowe.'):format(label)
    end

    value = trim(value)

    if #value < minLength or #value > maxLength then
        return nil, ('Pole %s musi mieć od %d do %d znaków.'):format(label, minLength, maxLength)
    end

    if value:find('[%c<>]') then
        return nil, ('Pole %s zawiera niedozwolone znaki.'):format(label)
    end

    return value
end

local function isLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0
end

local function daysInMonth(year, month)
    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if month == 2 and isLeapYear(year) then
        return 29
    end
    return days[month] or 0
end

local function sanitizeDate(value)
    if type(value) ~= 'string' then
        return nil, 'Data urodzenia jest nieprawidłowa.'
    end

    value = trim(value)

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    if not year then
        day, month, year = value:match('^(%d%d)%.(%d%d)%.(%d%d%d%d)$')
    end

    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)

    local currentYear = tonumber(os.date('%Y'))
    if not year or not month or not day or year < 1900 or year > currentYear then
        return nil, 'Data urodzenia jest poza dozwolonym zakresem.'
    end

    if month < 1 or month > 12 or day < 1 or day > daysInMonth(year, month) then
        return nil, 'Data urodzenia nie istnieje.'
    end

    local birthTime = os.time({ year = year, month = month, day = day, hour = 12 })
    if birthTime and birthTime > os.time() then
        return nil, 'Data urodzenia nie może być z przyszłości.'
    end

    return ('%04d-%02d-%02d'):format(year, month, day)
end

local function getIdentifier(source)
    if GetPlayerIdentifierByType then
        local license = GetPlayerIdentifierByType(source, 'license')
        if license and license ~= '' then
            return license
        end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:find('license:', 1, true) then
            return identifier
        end
    end

    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:find('steam:', 1, true) then
            return identifier
        end
    end

    return nil
end

local function decodeJson(value, fallback)
    if type(value) == 'table' then
        return value
    end

    if type(value) ~= 'string' or value == '' then
        return copyTable(fallback)
    end

    local ok, decoded = pcall(json.decode, value)
    if ok and type(decoded) == 'table' then
        return decoded
    end

    return copyTable(fallback)
end

local function sanitizeCoords(coords)
    coords = type(coords) == 'table' and coords or Config.DefaultCoords

    return {
        x = roundTwo(clampNumber(coords.x, -10000.0, 10000.0, false)),
        y = roundTwo(clampNumber(coords.y, -10000.0, 10000.0, false)),
        z = roundTwo(clampNumber(coords.z, -1000.0, 2000.0, false)),
        h = roundTwo(clampNumber(coords.h or coords.heading, 0.0, 360.0, false))
    }
end

local ComponentIds = { '1', '3', '4', '5', '6', '7', '8', '9', '10', '11' }
local PropIds = { '0', '1', '2', '3', '4', '5', '6', '7' }

local function sanitizeAppearanceItems(inputMap, defaults, ids, minDrawable)
    local sanitized = {}
    inputMap = type(inputMap) == 'table' and inputMap or {}

    for _, id in ipairs(ids) do
        local inputItem = inputMap[id] or inputMap[tonumber(id)] or {}
        local defaultItem = defaults[id] or { drawable = minDrawable, texture = 0 }

        if type(inputItem) ~= 'table' then
            inputItem = {}
        end

        sanitized[id] = {
            drawable = clampNumber(inputItem.drawable or inputItem[1] or defaultItem.drawable, minDrawable, 4096, true),
            texture = clampNumber(inputItem.texture or inputItem[2] or defaultItem.texture, 0, 255, true)
        }
    end

    return sanitized
end

local function sanitizeSkin(input, gender)
    gender = gender == 'female' and 'female' or 'male'

    local skin = copyTable(DefaultSkin[gender])
    input = type(input) == 'table' and input or {}

    local face = type(input.face) == 'table' and input.face or {}
    skin.face.mother = clampNumber(face.mother, 0, 45, true)
    skin.face.father = clampNumber(face.father, 0, 45, true)
    skin.face.shapeMix = roundTwo(clampNumber(face.shapeMix, 0.0, 1.0, false))
    skin.face.skinMix = roundTwo(clampNumber(face.skinMix, 0.0, 1.0, false))

    local hair = type(input.hair) == 'table' and input.hair or {}
    skin.hair.style = clampNumber(hair.style, 0, 4096, true)
    skin.hair.color = clampNumber(hair.color, 0, 63, true)
    skin.hair.highlight = clampNumber(hair.highlight, 0, 63, true)

    local overlays = type(input.overlays) == 'table' and input.overlays or {}
    skin.overlays.beard = clampNumber(overlays.beard, -1, 30, true)
    skin.overlays.beardOpacity = roundTwo(clampNumber(overlays.beardOpacity, 0.0, 1.0, false))
    skin.overlays.beardColor = clampNumber(overlays.beardColor, 0, 63, true)
    skin.overlays.eyebrows = clampNumber(overlays.eyebrows, -1, 34, true)
    skin.overlays.eyebrowsOpacity = roundTwo(clampNumber(overlays.eyebrowsOpacity, 0.0, 1.0, false))
    skin.overlays.eyebrowsColor = clampNumber(overlays.eyebrowsColor, 0, 63, true)
    skin.overlays.makeup = clampNumber(overlays.makeup, -1, 75, true)
    skin.overlays.makeupOpacity = roundTwo(clampNumber(overlays.makeupOpacity, 0.0, 1.0, false))

    skin.eyeColor = clampNumber(input.eyeColor, 0, 31, true)

    local components = type(input.components) == 'table' and input.components or {}
    local legacyClothes = type(input.clothes) == 'table' and input.clothes or nil

    if legacyClothes and not next(components) then
        components = {
            ['4'] = { drawable = legacyClothes.legs, texture = legacyClothes.legsTexture },
            ['6'] = { drawable = legacyClothes.shoes, texture = legacyClothes.shoesTexture },
            ['8'] = { drawable = legacyClothes.tshirt, texture = legacyClothes.tshirtTexture },
            ['11'] = { drawable = legacyClothes.torso, texture = legacyClothes.torsoTexture }
        }
    end

    skin.components = sanitizeAppearanceItems(components, skin.components, ComponentIds, 0)
    skin.props = sanitizeAppearanceItems(input.props, skin.props, PropIds, -1)

    skin.model = gender == 'female' and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    return skin
end

local function sanitizeCharacterPayload(payload)
    if type(payload) ~= 'table' then
        return nil, 'Nieprawidłowe dane postaci.'
    end

    local slot = tonumber(payload.slot)
    if not slot or slot ~= math.floor(slot) or slot < 1 or slot > Config.MaxCharacters then
        return nil, 'Nieprawidłowy slot postaci.'
    end

    local firstname, firstError = sanitizeText(payload.firstname, 2, 32, 'imię')
    if not firstname then
        return nil, firstError
    end

    local lastname, lastError = sanitizeText(payload.lastname, 2, 32, 'nazwisko')
    if not lastname then
        return nil, lastError
    end

    local nationality, nationalityError = sanitizeText(payload.nationality, 2, 48, 'pochodzenie')
    if not nationality then
        return nil, nationalityError
    end

    local dateofbirth, dateError = sanitizeDate(payload.dateofbirth)
    if not dateofbirth then
        return nil, dateError
    end

    local gender = payload.gender == 'female' and 'female' or payload.gender == 'male' and 'male' or nil
    if not gender then
        return nil, 'Płeć jest nieprawidłowa.'
    end

    local height = clampNumber(payload.height, Config.MinHeight, Config.MaxHeight, true)
    if tonumber(payload.height) ~= height then
        return nil, ('Wzrost musi być w zakresie %d-%d cm.'):format(Config.MinHeight, Config.MaxHeight)
    end

    return {
        slot = slot,
        firstname = firstname,
        lastname = lastname,
        nationality = nationality,
        dateofbirth = dateofbirth,
        height = height,
        gender = gender,
        skin = sanitizeSkin(payload.skin, gender)
    }
end

local function publicCharacter(character)
    return {
        id = tonumber(character.id),
        slot = tonumber(character.slot),
        firstname = character.firstname,
        lastname = character.lastname,
        nationality = character.nationality,
        dateofbirth = character.dateofbirth,
        height = tonumber(character.height),
        gender = character.gender
    }
end

local function characterFromRow(row)
    local gender = row.gender == 'female' and 'female' or 'male'

    return {
        id = tonumber(row.id),
        slot = tonumber(row.slot),
        identifier = row.identifier,
        firstname = row.firstname,
        lastname = row.lastname,
        nationality = row.nationality,
        dateofbirth = row.dateofbirth,
        height = tonumber(row.height),
        gender = gender,
        skin = sanitizeSkin(decodeJson(row.skin, DefaultSkin[gender]), gender),
        coords = sanitizeCoords(decodeJson(row.coords, Config.DefaultCoords))
    }
end

local function getServerPedCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end

    local coords = GetEntityCoords(ped)
    if not coords or (coords.x == 0.0 and coords.y == 0.0 and coords.z == 0.0) then
        return nil
    end

    return sanitizeCoords({
        x = coords.x,
        y = coords.y,
        z = coords.z,
        h = GetEntityHeading(ped)
    })
end

local function persistActiveCoords(source)
    local active = ActiveCharacters[source]
    if not active or not active.id then
        return
    end

    local safeCoords = getServerPedCoords(source)
    if not safeCoords then
        return
    end

    active.coords = safeCoords

    MySQL.update(
        'UPDATE characters SET coords = ? WHERE id = ? AND identifier = ?',
        { json.encode(safeCoords), active.id, active.identifier }
    )
end

local function loadCharacters(identifier)
    local rows = MySQL.query.await(
        'SELECT id, slot, firstname, lastname, nationality, dateofbirth, height, gender FROM characters WHERE identifier = ? ORDER BY slot ASC',
        { identifier }
    ) or {}

    local characters = {}
    for _, row in ipairs(rows) do
        characters[#characters + 1] = publicCharacter(row)
    end

    return characters
end

RegisterNetEvent('n33s_creator:server:loadCharacters', function(requestId)
    local source = source
    local identifier = getIdentifier(source)

    if not identifier then
        respond(source, requestId, { ok = false, error = 'Nie wykryto license/steam identifier.' })
        return
    end

    if not ensureDatabase() then
        respond(source, requestId, { ok = false, error = 'Baza danych nie jest gotowa. Sprawdź oxmysql i uprawnienia CREATE TABLE.' })
        return
    end

    local ok, result = pcall(loadCharacters, identifier)
    if not ok then
        print(('[n33s_creator] loadCharacters error for %s: %s'):format(identifier, result))
        respond(source, requestId, { ok = false, error = 'Błąd bazy danych podczas pobierania postaci.' })
        return
    end

    respond(source, requestId, {
        ok = true,
        maxCharacters = Config.MaxCharacters,
        characters = result
    })
end)

RegisterNetEvent('n33s_creator:server:playCharacter', function(requestId, payload)
    local source = source
    local identifier = getIdentifier(source)
    local characterId = type(payload) == 'table' and tonumber(payload.id) or nil

    if not identifier or not characterId then
        respond(source, requestId, { ok = false, error = 'Nieprawidłowe żądanie wyboru postaci.' })
        return
    end

    if not ensureDatabase() then
        respond(source, requestId, { ok = false, error = 'Baza danych nie jest gotowa.' })
        return
    end

    local ok, row = pcall(function()
        return MySQL.single.await('SELECT * FROM characters WHERE id = ? AND identifier = ? LIMIT 1', { characterId, identifier })
    end)

    if not ok then
        print(('[n33s_creator] playCharacter db error for %s: %s'):format(identifier, row))
        respond(source, requestId, { ok = false, error = 'Błąd bazy danych podczas wyboru postaci.' })
        return
    end

    if not row then
        respond(source, requestId, { ok = false, error = 'Ta postać nie istnieje lub nie należy do Ciebie.' })
        return
    end

    local character = characterFromRow(row)
    ActiveCharacters[source] = character

    respond(source, requestId, {
        ok = true,
        character = publicCharacter(character),
        spawn = {
            coords = character.coords,
            skin = character.skin,
            gender = character.gender
        }
    })
end)

RegisterNetEvent('n33s_creator:server:createCharacter', function(requestId, payload)
    local source = source
    local identifier = getIdentifier(source)

    if not identifier then
        respond(source, requestId, { ok = false, error = 'Nie wykryto license/steam identifier.' })
        return
    end

    if not ensureDatabase() then
        respond(source, requestId, { ok = false, error = 'Baza danych nie jest gotowa.' })
        return
    end

    if CreatingPlayers[source] then
        respond(source, requestId, { ok = false, error = 'Tworzenie postaci już trwa.' })
        return
    end

    local sanitized, validationError = sanitizeCharacterPayload(payload)
    if not sanitized then
        respond(source, requestId, { ok = false, error = validationError })
        return
    end

    CreatingPlayers[source] = true

    local ok, character, domainError = pcall(function()
        local countRows = MySQL.query.await('SELECT COUNT(*) AS count FROM characters WHERE identifier = ?', { identifier }) or {}
        local count = tonumber(countRows[1] and countRows[1].count) or 0

        if count >= Config.MaxCharacters then
            return nil, 'Osiągnięto maksymalną liczbę postaci.'
        end

        local slotRows = MySQL.query.await('SELECT id FROM characters WHERE identifier = ? AND slot = ? LIMIT 1', { identifier, sanitized.slot }) or {}
        if slotRows[1] then
            return nil, 'Ten slot jest już zajęty.'
        end

        local coords = sanitizeCoords(Config.DefaultCoords)
        local insertId = MySQL.insert.await(
            'INSERT INTO characters (identifier, slot, firstname, lastname, nationality, dateofbirth, height, gender, skin, coords) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
            {
                identifier,
                sanitized.slot,
                sanitized.firstname,
                sanitized.lastname,
                sanitized.nationality,
                sanitized.dateofbirth,
                sanitized.height,
                sanitized.gender,
                json.encode(sanitized.skin),
                json.encode(coords)
            }
        )

        if not insertId then
            return nil, 'Nie udało się zapisać postaci.'
        end

        local createdCharacter = {
            id = insertId,
            slot = sanitized.slot,
            identifier = identifier,
            firstname = sanitized.firstname,
            lastname = sanitized.lastname,
            nationality = sanitized.nationality,
            dateofbirth = sanitized.dateofbirth,
            height = sanitized.height,
            gender = sanitized.gender,
            skin = sanitized.skin,
            coords = coords
        }

        return createdCharacter
    end)

    CreatingPlayers[source] = nil

    if not ok then
        print(('[n33s_creator] createCharacter db error for %s: %s'):format(identifier, character))
        respond(source, requestId, { ok = false, error = 'Błąd bazy danych podczas zapisu postaci.' })
        return
    end

    if not character then
        respond(source, requestId, { ok = false, error = domainError or 'Nie udało się utworzyć postaci.' })
        return
    end

    ActiveCharacters[source] = character

    respond(source, requestId, {
        ok = true,
        character = publicCharacter(character),
        spawn = {
            coords = character.coords,
            skin = character.skin,
            gender = character.gender
        }
    })
end)

RegisterNetEvent('n33s_creator:server:saveCoords', function()
    persistActiveCoords(source)
end)

local function buildIdCard(character)
    return {
        firstname = character.firstname,
        lastname = character.lastname,
        nationality = character.nationality,
        dateofbirth = character.dateofbirth,
        height = character.height,
        gender = character.gender,
        labelGender = character.gender == 'female' and 'Kobieta' or 'Mężczyzna'
    }
end

local function showIdCard(source)
    local now = os.time()
    if LastIdCardRequest[source] and now - LastIdCardRequest[source] < 1 then
        return
    end

    LastIdCardRequest[source] = now

    local character = ActiveCharacters[source]

    if not character then
        TriggerClientEvent('n33s_creator:client:notify', source, 'Najpierw wybierz postać.')
        return
    end

    TriggerClientEvent('n33s_creator:client:showIdCard', source, buildIdCard(character))
end

RegisterNetEvent('n33s_creator:server:requestIdCard', function()
    showIdCard(source)
end)

RegisterCommand('dowod', function(source)
    if source == 0 then
        print('[n33s_creator] Komenda /dowod jest dostępna tylko dla gracza.')
        return
    end

    showIdCard(source)
end, false)

AddEventHandler('playerDropped', function()
    local source = source
    persistActiveCoords(source)
    ActiveCharacters[source] = nil
    CreatingPlayers[source] = nil
    LastIdCardRequest[source] = nil
end)
