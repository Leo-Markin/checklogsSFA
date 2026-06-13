script_name("checklogs")
script_version("15")
script_author("Неадекват, ЧСВ, Оскорбление DIS, Слив инфы DIS, хейтер DIS, Слив состава (Выход запрещён), Разжигатель вражды между USAF и DIS, (СЛИТ), Расформировал DIS, Разрушитель идеологии DIS или просто Leo_Markin")
script_description("Проверяет ЧС SFA, реестр наказаний SFA, логи SFA")
script_properties("work-in-pause")


-- ============================================================
-- Автозагрузка зависимостей
-- Логика: скачиваем ? выходим через return ? reload() перезапустит скрипт.
-- ============================================================
local function ensureLib(filename, url)
    local path = getWorkingDirectory() .. "\\lib\\" .. filename
    if doesFileExist(path) then return true end

    sampAddChatMessage("[checklogs] Скачиваю " .. filename .. ", подождите...", 0xFFFF00)

    local done = false
    local success = false

    downloadUrlToFile(url, path, function(id, status)
        local dl = require("moonloader").download_status
        if status == dl.STATUSEX_ENDDOWNLOAD then
            success = doesFileExist(path)
            done = true
        end
    end)

    lua_thread.create(function()
        while not done do wait(100) end
        if success then
            sampAddChatMessage("[checklogs] " .. filename .. " скачана! Перезапустите скрипт (CTRL + R)", 0x00FA9A)
        else
            sampAddChatMessage("[checklogs] Ошибка загрузки " .. filename .. "! Скачайте вручную: " .. url, 0xFF4444)
        end
    end)

    return false
end

-- Список библиотек для автозагрузки
local LIBS = {
    {
        file = "slowAES_l51.lua",
        url  = "https://raw.githubusercontent.com/Leo-Markin/checklogsSFA/main/lib/slowAES_l51.lua",
    },
    -- { file = "other_lib.lua", url = "https://..." },
}
for _, lib in ipairs(LIBS) do
    if not ensureLib(lib.file, lib.url) then
        return  -- скачивание запущено, ждём reload() из callback'а
    end
end

local enable_autoupdate = true
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Загружено %d из %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('Загрузка обновления завершена.')sampAddChatMessage(b..'Обновление завершено!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'Обновление прошло неудачно. Запускаю устаревшую версию..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': Обновление не требуется.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Смиритесь или проверьте самостоятельно на '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/Leo-Markin/checklogsSFA/main/version.json?" .. tostring(os.clock())
            Update.prefix = "[" .. thisScript().name .. "]: "
            Update.url = "https://raw.githubusercontent.com/Leo-Markin/checklogsSFA/main/checklogs.lua"
        end
    end
end

require "lib.moonloader"
local encoding = require "encoding"
encoding.default = "CP1251"
u8 = encoding.UTF8
local json = require "json"
local effil = require "effil"
local inicfg = require "inicfg"
local slowAES = require "lib.slowAES_l51"

local mainIni = inicfg.load({
    sroks = {
        r0  = -1,
        r1  = 0,
        r2  = 3,
        r3  = 3,
        r4  = 3,
        r5  = 5,
        r6  = 5,
        r7  = 7,
        r8  = 7,
        r9  = 7,
        r10 = 12,
        r11 = 12,
        r12 = 12,
        r13 = 12,
        r14 = 12,
        r15 = 30,
    }
}, "sroki_sfa")
inicfg.save(mainIni)

-- ============================================================
-- Вспомогательные функции
-- ============================================================

function google_decode(str)
    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x, 16)) end)
    str = str:gsub('\\"', '"')
    str = str:gsub('\\/', '/')
    str = str:gsub('\\\\', '\\')
    return str
end

function addDaysToDateString(dateString, daysToAdd)
    if daysToAdd == -1 then return "Нет срока" end
    local day, month, year, hour, minute = dateString:match("^(%d%d)%.(%d%d)%.(%d+) (%d%d):(%d%d)$")
    day    = tonumber(day)
    month  = tonumber(month)
    year   = tonumber(year)
    hour   = tonumber(hour)
    minute = tonumber(minute)
    if tostring(year):len() == 2 then year = year + 2000 end
    local t       = os.time({ year = year, month = month, day = day, hour = hour, min = minute, sec = 0 })
    local newDate = os.date("*t", t + daysToAdd * 86400)
    return string.format("%02d.%02d.%d", newDate.day, newDate.month, newDate.year)
end

-- Таблица соответствия ранг ? срок (дни)
local rankToField = {
    ["Рядовой [1]"]             = "r1",
    ["Ефрейтор [2]"]            = "r2",
    ["Младший сержант [3]"]     = "r3",
    ["Сержант [4]"]             = "r4",
    ["Старший сержант [5]"]     = "r5",
    ["Старшина [6]"]            = "r6",
    ["Прапорщик [7]"]           = "r7",
    ["Младший лейтенант [8]"]   = "r8",
    ["Лейтенант [9]"]           = "r9",
    ["Старший лейтенант [10]"]  = "r10",
    ["Капитан [11]"]            = "r11",
    ["Майор [12]"]              = "r12",
    ["Подполковник [13]"]       = "r13",
    ["Полковник [14]"]          = "r14",
    ["Генерал [15]"]            = "r15",
}
function getSrok(rank)
    local field = rankToField[rank]
    return field and mainIni.sroks[field] or mainIni.sroks.r0
end

-- Pending HTTP callbacks (resolve/reject), drained from main()'s loop so they
-- never run inside the polling coroutine. This prevents
-- "cannot resume non-suspended coroutine" when a callback starts a nested
-- asyncHttpRequest (e.g. /getrank does POST then GET on a found nick).
local pendingHttpCallbacks = {}

local function queueHttpCallback(fn)
    pendingHttpCallbacks[#pendingHttpCallbacks + 1] = fn
end

function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function(method, url, args)
        local requests = require "requests_script"
        local result, response = pcall(requests.request, method, url, args)
        if result then
            response.json, response.xml = nil, nil
            return true, response
        else
            return false, response
        end
    end)(method, url, args)
    resolve = resolve or function() end
    reject  = reject  or function() end
    lua_thread.create(function()
        local runner = request_thread
        while true do
            local status, err = runner:status()
            if not err then
                if status == "completed" then
                    local result, response = runner:get()
                    -- Defer off the polling coroutine: queue, main() runs it.
                    if result then
                        queueHttpCallback(function() resolve(response) end)
                    else
                        queueHttpCallback(function() reject(response) end)
                    end
                    return
                elseif status == "canceled" then
                    queueHttpCallback(function() reject(status) end)
                    return
                end
            else
                queueHttpCallback(function() reject(err) end)
                return
            end
            wait(0)
        end
    end)
end

-- ============================================================
-- AES-челлендж
-- ============================================================

local function hex2bytes(hex)
    local bytes = {}
    for i = 1, #hex, 2 do
        bytes[#bytes + 1] = tonumber(hex:sub(i, i + 1), 16)
    end
    return bytes
end

local function bytes2hex(bytes)
    local t = {}
    for i = 1, #bytes do t[i] = string.format("%02x", bytes[i]) end
    return table.concat(t)
end

-- Единственная кука которую проверяет сервер — R3ACTLB.
-- Получается автоматически решением AES-челленджа.
local currentR3ACTLB = nil

local function buildCookieHeader()
    if currentR3ACTLB then
        return "R3ACTLB=" .. currentR3ACTLB
    end
    return ""
end

local function solveChallenge(html)
    local a, b, c = html:match('"([a-f0-9]+)","([a-f0-9]+)","([a-f0-9]+)"')
    if not a or #a ~= 32 or #b ~= 32 or #c ~= 32 then return nil end
    local pt = slowAES:decrypt(hex2bytes(c), 2, hex2bytes(a), hex2bytes(b))
    return bytes2hex(pt)
end

-- ============================================================
-- POST-запрос с авто-решением челленджа
-- ============================================================

local function doPostRequest(params, headers, retry)
    retry = retry or 0
    if retry > 2 then
        sampAddChatMessage("Не удалось выполнить запрос после нескольких попыток", -1)
        return
    end

    headers["Cookie"]         = buildCookieHeader()
    headers["Content-Length"] = tostring(#headers.data)

    asyncHttpRequest("POST", "https://logs.evolve-rp.ru/saint-louis/journal",
        { headers = headers, data = headers.data },
        function(response)
            if response.status_code ~= 200 then
                sampAddChatMessage("Ошибка загрузки логов! Код: " .. response.status_code, -1)
                return
            end

            local text = response.text

            -- Антибот-челлендж: сервер вернул HTML вместо JSON
            if text:match("^<!DOCTYPE html>") or text:match("<html") then
                local token = solveChallenge(text)
                if token then
                    currentR3ACTLB = token
                    doPostRequest(params, headers, retry + 1)
                else
                    sampAddChatMessage("Не удалось решить челлендж, попробуйте позже", -1)
                end
                return
            end

            -- Обычный JSON-ответ
            local ok, jsonData = pcall(json.decode, text)
            if not ok then
                sampAddChatMessage("Ошибка разбора JSON", -1)
                return
            end
            if #jsonData.data == 0 then
                sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в логах не обнаружен!", params[1]), 0x00FA9A)
                return
            end

            -- Получаем данные о выговорах параллельно с выводом
            asyncHttpRequest("GET",
                "https://script.google.com/macros/s/AKfycbyNToZlIqnWl7mqaW4FjjHIjzMAJVPQ0OKBHWvdtTok9xOV6pt3rHzb0HsDrTKbkbHj/exec?nickname=" .. params[1],
                nil,
                function(response)
                    local html      = u8:decode(response.text)
                    local warnings  = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
                    local count     = math.min(params[2], #jsonData.data)
                    local rank      = u8:decode(jsonData.data[1][6])

                    local function printLines()
                        for i = count, 1, -1 do
                            local line = jsonData.data[i]
                            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                            sampAddChatMessage(string.format("{00FA9A}Инициатор:{ffffff} %s | {00FA9A}Объект:{ffffff} %s | {00FA9A}Действие: {ffffff}%s",
                                line[2], line[3], u8:decode(line[4])), 0x00FA9A)
                            sampAddChatMessage(string.format("{00FA9A}Старый ранг:{ffffff} %s | {00FA9A}Новый ранг:{ffffff} %s | {00FA9A}Причина: {ffffff}%s",
                                u8:decode(line[5]), u8:decode(line[6]), u8:decode(line[7])), 0x00FA9A)
                            sampAddChatMessage(string.format("{00FA9A}Дата: {ffffff}%s | {00FA9A}Следующее повышение:{ffffff} %s",
                                line[8], addDaysToDateString(line[8], getSrok(u8:decode(line[6])))), 0x00FA9A)
                            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                        end
                        if warnings and warnings ~= "-1" then
                            sampAddChatMessage(string.format("{FF0000}Есть выговоры до %s", warnings), 0x00FA9A)
                        end
                    end

                    -- Для сержантского состава дополнительно проверяем контракт
                    local sergeantRanks = {
                        ["Младший сержант [3]"] = true,
                        ["Сержант [4]"]         = true,
                        ["Старший сержант [5]"] = true,
                    }
                    if sergeantRanks[rank] then
                        asyncHttpRequest("GET",
                            "https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?contract=" .. params[1],
                            nil,
                            function(response)
                                local h = u8:decode(response.text)
                                local contract = u8:decode(h:gmatch('userHtml\\x22:\\x22(.-)\\x22')())
                                printLines()
                                if contract ~= "Нет контракта" then
                                    sampAddChatMessage(string.format("{00FA9A}На военной кафедре/контракте до:{ffffff} %s", contract), 0x00FA9A)
                                end
                            end,
                            function(err) print(err) end
                        )
                    else
                        printLines()
                    end
                end,
                function(err) print(err) end
            )
        end,
        function(err) print(err) end
    )
end

local function register_checklogs_commands(unregister_first)
    local cmds = {
        {"getbl",         cmd_getbl},
        {"getpun",        cmd_getpun},
        {"getrank",       cmd_getrank},
        {"invite",        cmd_invite},
        {"checkcontract", cmd_checkcontract},
        {"contracts",     cmd_contracts},
        {"acccontract",   cmd_acccontract},
        {"logshelp",      cmd_logshelp},
    }

    for _, data in ipairs(cmds) do
        if unregister_first then
            pcall(sampUnregisterChatCommand, data[1])
        end
        sampRegisterChatCommand(data[1], data[2])
    end
end
-- ============================================================
-- main
-- ============================================================

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    --wait(5000)
    register_checklogs_commands(true)
    sampAddChatMessage("checklogs by Leo_Markin v15 loaded. {FFFFFF}/logshelp{00FA9A} - список команд", 0x00FA9A)
    print("checklogs by Leo_Markin v15 loaded.")

    -- Drain HTTP callbacks on the main thread so a callback can safely start
    -- another asyncHttpRequest without reentering a polling coroutine.
    while true do
        if #pendingHttpCallbacks > 0 then
            local callbacks = pendingHttpCallbacks
            pendingHttpCallbacks = {}
            for _, fn in ipairs(callbacks) do
                local ok, err = pcall(fn)
                if not ok then print("[checklogs] callback error: " .. tostring(err)) end
            end
        end
        wait(0)
    end
end

-- ============================================================
-- Команды
-- ============================================================

function cmd_getbl(arg)
    if #arg == 0 then
        sampAddChatMessage("Введите: /getbl [id / nick]", 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbxwOW4H6tOcVXtQbwoEc8EzZEl9g1dEPJCUp6D1Fbjq0T6PVKoPv2qI48elNt6TU20txA/exec?nickname=" .. arg,
        nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            if not data then
                sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в чёрном списке не обнаружен!", arg), 0x00FA9A)
                return
            end
            local info = {}
            for j in data:gmatch("([^,]+)") do info[#info + 1] = j end
            if info[5] == "6" then info[5] = "Вынесен" end
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Внёс:{ffffff} %s | {00FA9A}Дата: {ffffff}%s", info[2], info[1], info[4]), 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Степень: {ffffff}%s | {00FA9A}Причина:{ffffff} %s", info[5], info[3]), 0x00FA9A)
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
        end,
        function(err) print(err) end
    )
end

function cmd_getpun(arg)
    if #arg == 0 then
        sampAddChatMessage("Введите: /getpun [id / nick]", 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbyNToZlIqnWl7mqaW4FjjHIjzMAJVPQ0OKBHWvdtTok9xOV6pt3rHzb0HsDrTKbkbHj/exec?getpun_nick=" .. arg,
        nil,
        function(response)
            if response.status_code ~= 200 and response.status_code ~= 302 then
                sampAddChatMessage("Ошибка подключения! Код: " .. response.status_code, 0x00FA9A)
                return
            end
            local clean = google_decode(response.text)
            local raw_json = clean:match("<data>(.-)</data>") or clean:match("<data>(.-)<\\/data>")
            if not raw_json then
                sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в реестре наказаний не обнаружен (или сбой парсинга)!", arg), 0x00FA9A)
                return
            end
            raw_json = raw_json:gsub('\\"', '"')
            local ok, jsonData = pcall(json.decode, raw_json)
            if not ok then
                sampAddChatMessage("Ошибка чтения JSON данных.", 0xFF0000)
                print("JSON FAIL: " .. raw_json)
                return
            end
            if #jsonData == 0 then
                sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в реестре наказаний не обнаружен!", arg), 0x00FA9A)
                return
            end
            for _, item in ipairs(jsonData) do
                local description = "Отсутствует"
                if item.description and item.description ~= "" and item.description ~= json.null then
                    description = u8:decode(item.description)
                end
                sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Выдал:{ffffff} %s | {00FA9A}Дата: {ffffff}%s",
                    u8:decode(item.violator), u8:decode(item.author), u8:decode(item.date)), 0x00FA9A)
                sampAddChatMessage(string.format("{00FA9A}Санкция: {ffffff}%s | {00FA9A}Причина:{ffffff} %s | {00FA9A}Описание:{ffffff} %s",
                    u8:decode(item.sanction), u8:decode(item.reason), description), 0x00FA9A)
                sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            end
        end,
        function(err)
            print(err)
            sampAddChatMessage("Критическая ошибка запроса.", 0xFF0000)
        end
    )
end

function cmd_getrank(args)
    if #args == 0 then
        sampAddChatMessage("Введите: /getrank [id / nick] (Количество записей max = 25)", 0x00FA9A)
        return
    end
    local params, i = {}, 1
    for arg in args:gmatch("[^%s]+") do params[i] = arg; i = i + 1 end
    params[2] = tonumber(params[2]) or 5
    if params[2] > 25 then
        sampAddChatMessage("Максимум 25 записей", 0x00FA9A)
        return
    end
    local id = tonumber(params[1])
    if id then
        if sampIsPlayerConnected(id) then
            params[1] = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end

    local body = "draw=9&columns%5B0%5D%5Bdata%5D=0&columns%5B0%5D%5Bname%5D=&columns%5B0%5D%5Bsearchable%5D=true&columns%5B0%5D%5Borderable%5D=true&columns%5B0%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B0%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B1%5D%5Bdata%5D=1&columns%5B1%5D%5Bname%5D=&columns%5B1%5D%5Bsearchable%5D=true&columns%5B1%5D%5Borderable%5D=true&columns%5B1%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B1%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B2%5D%5Bdata%5D=2&columns%5B2%5D%5Bname%5D=&columns%5B2%5D%5Bsearchable%5D=true&columns%5B2%5D%5Borderable%5D=true&columns%5B2%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B2%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B3%5D%5Bdata%5D=3&columns%5B3%5D%5Bname%5D=&columns%5B3%5D%5Bsearchable%5D=true&columns%5B3%5D%5Borderable%5D=true&columns%5B3%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B3%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B4%5D%5Bdata%5D=4&columns%5B4%5D%5Bname%5D=&columns%5B4%5D%5Bsearchable%5D=true&columns%5B4%5D%5Borderable%5D=true&columns%5B4%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B4%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B5%5D%5Bdata%5D=5&columns%5B5%5D%5Bname%5D=&columns%5B5%5D%5Bsearchable%5D=true&columns%5B5%5D%5Borderable%5D=true&columns%5B5%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B5%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B6%5D%5Bdata%5D=6&columns%5B6%5D%5Bname%5D=&columns%5B6%5D%5Bsearchable%5D=true&columns%5B6%5D%5Borderable%5D=true&columns%5B6%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B6%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B7%5D%5Bdata%5D=7&columns%5B7%5D%5Bname%5D=&columns%5B7%5D%5Bsearchable%5D=true&columns%5B7%5D%5Borderable%5D=true&columns%5B7%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B7%5D%5Bsearch%5D%5Bregex%5D=false&order%5B0%5D%5Bcolumn%5D=7&order%5B0%5D%5Bdir%5D=desc&start=0&length=25&search%5Bvalue%5D=" .. params[1] .. "&search%5Bregex%5D=false&fraction=3"

    local headers = {
        ["X-KL-Ajax-Request"] = "Ajax_Request",
        ["User-Agent"]        = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36",
        ["Content-Type"]      = "application/x-www-form-urlencoded; charset=UTF-8",
        ["Accept"]            = "application/json, text/javascript, */*; q=0.01",
        ["Referer"]           = "https://logs.evolve-rp.ru/saint-louis",
        ["Origin"]            = "https://logs.evolve-rp.ru",
        ["X-Requested-With"]  = "XMLHttpRequest",
        data = body,
    }

    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    doPostRequest(params, headers)
end

function cmd_invite(args)
    if #args == 0 then
        sampAddChatMessage("Введите: /invite [id] [1 - принять без проверки на ЧС]", 0x00FA9A)
        return
    end
    local params, i = {}, 1
    for arg in args:gmatch("[^%s]+") do params[i] = arg; i = i + 1 end
    params[2] = tonumber(params[2])
    if params[2] == 1 then
        sampSendChat("/invite " .. params[1])
        return
    end
    local id = tonumber(params[1])
    if id then
        if sampIsPlayerConnected(id) then
            params[1] = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbxwOW4H6tOcVXtQbwoEc8EzZEl9g1dEPJCUp6D1Fbjq0T6PVKoPv2qI48elNt6TU20txA/exec?nickname=" .. params[1],
        nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            if not data then
                sampSendChat("/invite " .. id)
                return
            end
            local info = {}
            for j in data:gmatch("([^,]+)") do info[#info + 1] = j end
            if info[5] == "6" then
                sampSendChat("/invite " .. id)
                return
            end
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Внёс:{ffffff} %s | {00FA9A}Дата: {ffffff}%s", info[2], info[1], info[4]), 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Степень: {ffffff}%s | {00FA9A}Причина:{ffffff} %s", info[5], info[3]), 0x00FA9A)
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
        end,
        function(err) print(err) end
    )
end

function cmd_checkcontract(arg)
    if #arg == 0 then
        sampAddChatMessage("Введите: /checkcontract [id / nick]", 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?nickname=" .. arg,
        nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            sampAddChatMessage(data, 0x00FA9A)
        end,
        function(err) print(err) end
    )
end

function cmd_contracts()
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec",
        nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            local found = false
            for nick in data:gmatch("([^,]+)") do
                local pid = sampGetPlayerIdByNickname(nick)
                if pid then
                    sampAddChatMessage(string.format("%s [%s]", nick, pid), 0x00FA9A)
                    found = true
                end
            end
            if not found then sampAddChatMessage("Список пуст", 0x00FA9A) end
        end,
        function(err) print(err) end
    )
end

function cmd_acccontract(arg)
    if #arg == 0 then
        sampAddChatMessage("Введите: /acccontract [id / nick]", 0x00FA9A)
        return
    end
    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local mynick  = sampGetPlayerNickname(myid)
    local id = tonumber(arg)
    if id then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage("Игрок оффлайн!", 0x00FA9A)
            return
        end
    end
    sampAddChatMessage("Загрузка данных...", 0x00FA9A)
    asyncHttpRequest("GET",
        "https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?nickname=" .. arg .. "&staff=" .. mynick,
        nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            sampAddChatMessage(data, 0x00FA9A)
        end,
        function(err) print(err) end
    )
end

function sampGetPlayerIdByNickname(nick)
    nick = tostring(nick)
    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if nick == sampGetPlayerNickname(myid) then return myid end
    for i = 0, 1003 do
        if sampIsPlayerConnected(i) and sampGetPlayerNickname(i) == nick then
            return i
        end
    end
end

function cmd_logshelp()
    sampShowDialog(1337, "{00FA9A}checklogs help",
        "{00FA9A}/getbl [id/nick]{FFFFFF} - Проверить игрока в ЧС SFA\n" ..
        "{00FA9A}/getpun [id/nick]{FFFFFF} - Проверить реестр наказаний\n" ..
        "{00FA9A}/getrank [id/nick] [кол-во]{FFFFFF} - Логи повышений/понижений (посл. 25)\n" ..
        "{00FA9A}/invite [id] [1]{FFFFFF} - Принять во фракцию с проверкой на ЧС; [1] - без проверки\n" ..
        "{00FA9A}/checkcontract [id/nick]{FFFFFF} - Проверить наличие одобренного контракта\n" ..
        "{00FA9A}/contracts{FFFFFF} - Список непринятых контрактников онлайн\n" ..
        "{00FA9A}/acccontract [id/nick]{FFFFFF} - Проставить принятие контрактника в таблице",
        "Закрыть", "", 0)
end
