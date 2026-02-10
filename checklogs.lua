script_name("checklogsSFA")
script_version("11")
script_author("Неадекват, ЧСВ, Оскорбление DIS, Слив инфы DIS, хейтер DIS, Слив состава (Выход запрещён), Разжигатель вражды между USAF и DIS, (СЛИТ), Расформировал DIS, Разрушитель идеологии DIS или просто Leo_Markin")
script_description("Проверяет ЧС SFA, реестр наказаний SFA, логи SFA")

local enable_autoupdate = true -- false to disable auto-update + disable sending initial telemetry (server, moonloader version, script version, samp nickname, virtual volume serial number)
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'Обнаружено обновление. Пытаюсь обновиться c '..thisScript().version..' на '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('Загружено %d из %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('Загрузка обновления завершена.')sampAddChatMessage(b..'Обновление завершено!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'Обновление прошло неудачно. Запускаю устаревшую версию..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': Обновление не требуется.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': Не могу проверить обновление. Смиритесь или проверьте самостоятельно на '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, выходим из ожидания проверки обновления. Смиритесь или проверьте самостоятельно на '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/Leo-Markin/checklogsSFA/main/version.json?" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = "https://github.com/Leo-Markin/checklogsSFA/"
        end
    end
end

require "lib.moonloader"
local encoding = require "encoding"
encoding.default = "CP1251"
u8 = encoding.UTF8
local json = require "json"
local effil = require 'effil'
local inicfg = require "inicfg"
local mainIni = inicfg.load({
    sroks =
    {
        r0 = -1,
        r1 = 0,
        r2 = 3,
        r3 = 3,
        r4 = 3,
        r5 = 5,
        r6 = 5,
        r7 = 7,
        r8 = 7,
        r9 = 7,
        r10 = 12,
        r11 = 12,
        r12 = 12,
        r13 = 12,
        r14 = 12,
        r15 = 30
    }
  }, "sroki_sfa")
inicfg.save(mainIni)

function google_decode(str)
    str = str:gsub("\\x(%x%x)", function(x) return string.char(tonumber(x, 16)) end)
    str = str:gsub('\\"', '"')
    str = str:gsub('\\/', '/')
    str = str:gsub('\\\\', '\\')
    return str
end

function addDaysToDateString(dateString, daysToAdd)
    if daysToAdd == -1 then
        return 'Нет срока'
    end
    local day, month, year, hour, minute = dateString:match("^(%d%d)%.(%d%d)%.(%d+) (%d%d):(%d%d)$")

    day = tonumber(day)
    month = tonumber(month)
    year = tonumber(year)
    hour = tonumber(hour)
    minute = tonumber(minute)

    if tostring(year):len() == 2 then
        year = year + 2000
    end
    
    local dateTable = {
      year = year,
      month = month,
      day = day,
      hour = hour,
      min = minute,
      sec = 0
    }
   
    local time = os.time(dateTable)
    local newTime = time + (daysToAdd * 24 * 60 * 60)
    local newDateTable = os.date("*t", newTime)
    local formattedDate = string.format("%02d.%02d.%d", newDateTable.day, newDateTable.month, newDateTable.year)
    return formattedDate
end

function getSrok(rank)
    if rank == "Рядовой [1]" then
        return mainIni.sroks.r1
    end
    if rank == "Ефрейтор [2]" then
        return mainIni.sroks.r2
    end
    if rank == "Младший сержант [3]" then
        return mainIni.sroks.r3
    end
    if rank == "Сержант [4]" then
        return mainIni.sroks.r4
    end
    if rank == "Старший сержант [5]" then
        return mainIni.sroks.r5
    end
    if rank == "Старшина [6]" then
        return mainIni.sroks.r6
    end
    if rank == "Прапорщик [7]" then
        return mainIni.sroks.r7
    end
    if rank == "Младший лейтенант [8]" then
        return mainIni.sroks.r8
    end
    if rank == "Лейтенант [9]" then
        return mainIni.sroks.r9
    end
    if rank == "Старший лейтенант [10]" then
        return mainIni.sroks.r10
    end
    if rank == "Капитан [11]" then
        return mainIni.sroks.r11
    end
    if rank == "Майор [12]" then
        return mainIni.sroks.r12
    end
    if rank == "Подполковник [13]" then
        return mainIni.sroks.r13
    end
    if rank == "Полковник [14]" then
        return mainIni.sroks.r14
    end
    if rank == "Генерал [15]" then
        return mainIni.sroks.r15
    end
    return mainIni.sroks.r0
end

function asyncHttpRequest(method, url, args, resolve, reject)
   local request_thread = effil.thread(function (method, url, args)
      local requests = require 'requests_script'
      local result, response = pcall(requests.request, method, url, args)
      if result then
         response.json, response.xml = nil, nil
         return true, response
      else
         return false, response
      end
   end)(method, url, args)
   if not resolve then resolve = function() end end
   if not reject then reject = function() end end
   lua_thread.create(function()
      local runner = request_thread
      while true do
         local status, err = runner:status()
         if not err then
            if status == 'completed' then
               local result, response = runner:get()
               if result then
                  resolve(response)
               else
                  reject(response)
               end
               return
            elseif status == 'canceled' then
               return reject(status)
            end
         else
            return reject(err)
         end
         wait(0)
      end
   end)
end

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    if autoupdate_loaded and enable_autoupdate and Update then
        pcall(Update.check, Update.json_url, Update.prefix, Update.url)
    end
    sampRegisterChatCommand("getbl", cmd_getbl)
    sampRegisterChatCommand("getpun", cmd_getpun)
    sampRegisterChatCommand("getrank", cmd_getrank)
    sampRegisterChatCommand("invite", cmd_invite)
    sampRegisterChatCommand("checkcontract", cmd_checkcontract)
    sampRegisterChatCommand("contracts", cmd_contracts)
    sampRegisterChatCommand("acccontract", cmd_acccontract)
    sampRegisterChatCommand("logshelp", cmd_logshelp)
    sampAddChatMessage(string.format("checklogs by Leo_Markin v11 loaded. {FFFFFF}/logshelp{00FA9A} - список команд"), 0x00FA9A)
    print("checklogs by Leo_Markin v11 loaded.")
    wait(-1)
end

function cmd_getbl(arg)
    if #arg == 0 then
        sampAddChatMessage('Введите: /getbl [id / nick]', 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
    asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxwOW4H6tOcVXtQbwoEc8EzZEl9g1dEPJCUp6D1Fbjq0T6PVKoPv2qI48elNt6TU20txA/exec?nickname=' .. arg, nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            if data == nil then
                sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в чёрном списке не обнаружен!", arg), 0x00FA9A)
                return
            end
            local info = {}
            for j in string.gmatch(data, '([^,]+)') do
                table.insert(info, j)
            end
            if info[5] == '6' then
                info[5] = "Вынесен"
            end
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Внёс:{ffffff} %s | {00FA9A}Дата: {ffffff}%s", info[2], info[1], info[4]), 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Степень: {ffffff}%s | {00FA9A}Причина:{ffffff} %s", info[5], info[3]), 0x00FA9A)
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            return
        end,
        function(err)
            print(err)
        end
    )
end



function cmd_getpun(arg)
    if #arg == 0 then
        sampAddChatMessage('Введите: /getpun [id / nick]', 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)

    local scriptUrl = 'https://script.google.com/macros/s/AKfycbyNToZlIqnWl7mqaW4FjjHIjzMAJVPQ0OKBHWvdtTok9xOV6pt3rHzb0HsDrTKbkbHj/exec'
    local requestUrl = scriptUrl .. '?getpun_nick=' .. arg

    asyncHttpRequest('GET', requestUrl, nil,
        function(response)
            if response.status_code == 200 or response.status_code == 302 then
                local clean_text = google_decode(response.text)
                local raw_json = clean_text:match('<data>(.-)</data>')
                if not raw_json then
                    raw_json = clean_text:match('<data>(.-)<\\/data>')
                end
                if not raw_json then
                    sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в реестре наказаний не обнаружен (или сбой парсинга)!", arg), 0x00FA9A)
                    return
                end
                raw_json = raw_json:gsub('\\"', '"')
                local result, jsonData = pcall(json.decode, raw_json)
                if not result then
                    sampAddChatMessage("Ошибка чтения JSON данных.", 0xFF0000)
                    print("JSON FAIL: " .. raw_json) 
                    return
                end
                if #jsonData == 0 then
                    sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в реестре наказаний не обнаружен!", arg), 0x00FA9A)
                    return
                end
                for i, item in ipairs(jsonData) do
                    local description = "Отсутствует"
                    if item.description and item.description ~= "" and item.description ~= json.null then
                        description = u8:decode(item.description)
                    end
                    local violator = u8:decode(item.violator)
                    local author = u8:decode(item.author)
                    local date = u8:decode(item.date)
                    local sanction = u8:decode(item.sanction)
                    local reason = u8:decode(item.reason)
                    sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                    sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Выдал:{ffffff} %s | {00FA9A}Дата: {ffffff}%s", violator, author, date), 0x00FA9A)
                    sampAddChatMessage(string.format("{00FA9A}Санкция: {ffffff}%s | {00FA9A}Причина:{ffffff} %s | {00FA9A}Описание:{ffffff} %s", sanction, reason, description), 0x00FA9A)
                    sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                end
            else
                sampAddChatMessage("Ошибка подключения! Код: " .. response.status_code, 0x00FA9A)
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
        sampAddChatMessage('Введите: /getrank [id / nick] (Количество записей max = 25)', 0x00FA9A)
        return
    end
    local params, i = {}, 1
    for arg in string.gmatch(args, "[^%s]+") do
        params[i] = arg
        i = i + 1
    end
    params[2] = tonumber(params[2])
    if params[2] == nil then params[2] = 5 end
    if params[2] > 25 then
        sampAddChatMessage('Максимум 25 записей', 0x00FA9A)
        return
    end
    local id = tonumber(params[1])
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            params[1] = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    local body = "draw=8&columns%5B0%5D%5Bdata%5D=0&columns%5B0%5D%5Bname%5D=&columns%5B0%5D%5Bsearchable%5D=true&columns%5B0%5D%5Borderable%5D=true&columns%5B0%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B0%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B1%5D%5Bdata%5D=1&columns%5B1%5D%5Bname%5D=&columns%5B1%5D%5Bsearchable%5D=true&columns%5B1%5D%5Borderable%5D=true&columns%5B1%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B1%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B2%5D%5Bdata%5D=2&columns%5B2%5D%5Bname%5D=&columns%5B2%5D%5Bsearchable%5D=true&columns%5B2%5D%5Borderable%5D=true&columns%5B2%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B2%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B3%5D%5Bdata%5D=3&columns%5B3%5D%5Bname%5D=&columns%5B3%5D%5Bsearchable%5D=true&columns%5B3%5D%5Borderable%5D=true&columns%5B3%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B3%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B4%5D%5Bdata%5D=4&columns%5B4%5D%5Bname%5D=&columns%5B4%5D%5Bsearchable%5D=true&columns%5B4%5D%5Borderable%5D=true&columns%5B4%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B4%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B5%5D%5Bdata%5D=5&columns%5B5%5D%5Bname%5D=&columns%5B5%5D%5Bsearchable%5D=true&columns%5B5%5D%5Borderable%5D=true&columns%5B5%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B5%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B6%5D%5Bdata%5D=6&columns%5B6%5D%5Bname%5D=&columns%5B6%5D%5Bsearchable%5D=true&columns%5B6%5D%5Borderable%5D=true&columns%5B6%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B6%5D%5Bsearch%5D%5Bregex%5D=false&columns%5B7%5D%5Bdata%5D=7&columns%5B7%5D%5Bname%5D=&columns%5B7%5D%5Bsearchable%5D=true&columns%5B7%5D%5Borderable%5D=true&columns%5B7%5D%5Bsearch%5D%5Bvalue%5D=&columns%5B7%5D%5Bsearch%5D%5Bregex%5D=false&order%5B0%5D%5Bcolumn%5D=7&order%5B0%5D%5Bdir%5D=desc&start=0&length=25&search%5Bvalue%5D=" .. params[1] .. "&search%5Bregex%5D=false&fraction=3"
    local headers = {
        ["X-KL-Ajax-Request"] = "Ajax_Request",
        ["sec-ch-ua"] = '"Not/A)Brand";v="8", "Chromium";v="126", "Google Chrome";v="126"',
        ["sec-ch-ua-mobile"] = "?0",
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8",
        ["Accept"] = "application/json, text/javascript, */*; q=0.01",
        ["Referer"] = "https://logs.evolve-rp.com/saint-louis",
        ["X-Requested-With"] = "XMLHttpRequest",
        ["sec-ch-ua-platform"] = '"Windows"',
        ["Content-Length"] = tostring(#body)
    }
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
    asyncHttpRequest('POST', 'https://logs.evolve-rp.com/saint-louis/journal', 
        {
            headers = headers,
            data = body
        },
        function(response)
            if response.status_code == 200 then
                local jsonData = json.decode(response.text)
                if #jsonData.data == 0 then
                    sampAddChatMessage(string.format("{ffffff}%s {00FA9A}в логах не обнаружен!", params[1]), 0x00FA9A)
                    return
                end
                asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbyNToZlIqnWl7mqaW4FjjHIjzMAJVPQ0OKBHWvdtTok9xOV6pt3rHzb0HsDrTKbkbHj/exec?nickname=' .. params[1], nil,
                    function(response)
                        local html = u8:decode(response.text)
                        local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
                        if #jsonData.data < params[2] then params[2] = #jsonData.data end
                        local rank = u8:decode(jsonData.data[1][6])
                        if rank == "Младший сержант [3]" or rank == "Сержант [4]" or rank == "Старший сержант [5]" then
                            asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?contract=' .. params[1], nil,
                                function(response)
                                    local html = u8:decode(response.text)
                                    data_contract = u8:decode(html:gmatch('userHtml\\x22:\\x22(.-)\\x22')())
                                    for i = params[2], 1, -1 do
                                        local line = jsonData.data[i]
                                        sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                                        sampAddChatMessage(string.format("{00FA9A}Инициатор:{ffffff} %s | {00FA9A}Объект:{ffffff} %s | {00FA9A}Действие: {ffffff}%s", line[2], line[3], u8:decode(line[4])), 0x00FA9A)
                                        sampAddChatMessage(string.format("{00FA9A}Старый ранг:{ffffff} %s | {00FA9A}Новый ранг:{ffffff} %s | {00FA9A}Причина: {ffffff}%s", u8:decode(line[5]), u8:decode(line[6]), u8:decode(line[7])), 0x00FA9A)
                                        sampAddChatMessage(string.format("{00FA9A}Дата: {ffffff}%s | {00FA9A}Следующее повышение:{ffffff} %s", line[8], addDaysToDateString(line[8], getSrok(u8:decode(line[6])))), 0x00FA9A)
                                        sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                                    end
                                    if data ~= '-1' then 
                                        sampAddChatMessage(string.format("{FF0000}Есть выговоры до %s", data), 0x00FA9A);
                                    end
                                    if data_contract ~= "Нет контракта" then
                                        sampAddChatMessage(string.format("{00FA9A}На военной кафедре/контракте до:{ffffff} %s", data_contract), 0x00FA9A)
                                    end
                                end,
                                function(err)
                                    print(err)
                                end
                            )
                        else
                            for i = params[2], 1, -1 do
                                local line = jsonData.data[i]
                                sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                                sampAddChatMessage(string.format("{00FA9A}Инициатор:{ffffff} %s | {00FA9A}Объект:{ffffff} %s | {00FA9A}Действие: {ffffff}%s", line[2], line[3], u8:decode(line[4])), 0x00FA9A)
                                sampAddChatMessage(string.format("{00FA9A}Старый ранг:{ffffff} %s | {00FA9A}Новый ранг:{ffffff} %s | {00FA9A}Причина: {ffffff}%s", u8:decode(line[5]), u8:decode(line[6]), u8:decode(line[7])), 0x00FA9A)
                                sampAddChatMessage(string.format("{00FA9A}Дата: {ffffff}%s | {00FA9A}Следующее повышение:{ffffff} %s", line[8], addDaysToDateString(line[8], getSrok(u8:decode(line[6])))), 0x00FA9A)
                                sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
                            end
                            if data ~= '-1' then 
                                sampAddChatMessage(string.format("{FF0000}Есть выговоры до %s", data), 0x00FA9A);
                            end
                        end
                        
                    end,
                    function(err)
                        print(err)
                    end
                )
            else sampAddChatMessage("Ошибка загрузки логов! Код: " .. response.status_code, 0x00FA9A) end
        end,
        function(err)
            print(err)
        end
    )
end

function cmd_invite(args)
    if #args == 0 then
        sampAddChatMessage('Введите: /invite [id] [1 - принять без проверки на ЧС]', 0x00FA9A)
        return
    end
    local params, i = {}, 1
    for arg in string.gmatch(args, "[^%s]+") do
        params[i] = arg
        i = i + 1
    end
    params[2] = tonumber(params[2])
    if params[2] == 1 then
        sampSendChat('/invite ' .. params[1])
        return
    end
    local id = tonumber(params[1])
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            params[1] = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
        asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxwOW4H6tOcVXtQbwoEc8EzZEl9g1dEPJCUp6D1Fbjq0T6PVKoPv2qI48elNt6TU20txA/exec?nickname=' .. params[1], nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            if data == nil then
                sampSendChat("/invite " .. id)
                return
            end
            local info = {}
            for j in string.gmatch(data, '([^,]+)') do
                table.insert(info, j)
            end
            if info[5] == '6' then
                sampSendChat("/invite " .. id)
                return
            end
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Ник:{ffffff} %s | {00FA9A}Внёс:{ffffff} %s | {00FA9A}Дата: {ffffff}%s", info[2], info[1], info[4]), 0x00FA9A)
            sampAddChatMessage(string.format("{00FA9A}Степень: {ffffff}%s | {00FA9A}Причина:{ffffff} %s", info[5], info[3]), 0x00FA9A)
            sampAddChatMessage("--------------------------------------------------------------------------------------------", 0x00FA9A)
            return
        end,
        function(err)
            print(err)
        end
    )
end

function cmd_checkcontract(arg)
    if #arg == 0 then
        sampAddChatMessage('Введите: /checkcontract [id / nick]', 0x00FA9A)
        return
    end
    local id = tonumber(arg)
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
    asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?nickname=' .. arg, nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            sampAddChatMessage(data, 0x00FA9A)
        end,
        function(err)
            print(err)
        end
    )
end

function cmd_contracts()
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
    asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec', nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            local flag = true
            for nick in string.gmatch(data, '([^,]+)') do
                local id = sampGetPlayerIdByNickname(nick)
                if id ~= nil then
                   sampAddChatMessage(string.format("%s [%s]", nick, id), 0x00FA9A) 
                   flag = false
                end
            end
            if flag then sampAddChatMessage("Список пуст", 0x00FA9A) end
        end,
        function(err)
            print(err)
        end
    )
end

function cmd_acccontract(arg)
    if #arg == 0 then
        sampAddChatMessage('Введите: /acccontract [id / nick]', 0x00FA9A)
        return
    end
    local _, myid = sampGetPlayerIdByCharHandle(PLAYER_PED)
    local mynick = sampGetPlayerNickname(myid)
    local id = tonumber(arg)
    if id ~= nil then
        if sampIsPlayerConnected(id) then
            arg = sampGetPlayerNickname(id)
        else
            sampAddChatMessage('Игрок оффлайн!', 0x00FA9A)
            return
        end
    end
    sampAddChatMessage('Загрузка данных...', 0x00FA9A)
    asyncHttpRequest('GET', 'https://script.google.com/macros/s/AKfycbxB7WwPsPpYHO5aPRdbrsrNuX2pZtS1s4GX8raft68PAX7BcKDee1GqVxUYCH2FrgiQ/exec?nickname=' .. arg .. '&staff=' .. mynick, nil,
        function(response)
            local html = u8:decode(response.text)
            local data = html:gmatch('userHtml\\x22:\\x22(.-)\\x22')()
            sampAddChatMessage(data, 0x00FA9A)
        end,
        function(err)
            print(err)
        end
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
    local text = "{00FA9A}/getbl [id/nick]{FFFFFF} - Проверить игрока в ЧС SFA\n" ..
                 "{00FA9A}/getpun [id/nick]{FFFFFF} - Проверить реестр наказаний\n" ..
                 "{00FA9A}/getrank [id/nick] [кол-во]{FFFFFF} - Логи повышений/понижений (посл. 25)\n" ..
                 "{00FA9A}/invite [id] [1]{FFFFFF} - Принять во фракцию с проверкой на ЧС; [1] - не делать проверку\n" ..
                 "{00FA9A}/checkcontract [id/nick]{FFFFFF} - Проверить наличие одобренного контракта\n" ..
                 "{00FA9A}/contracts{FFFFFF} - Список непринятых контрактников онлайн\n" ..
                 "{00FA9A}/acccontract [id/nick]{FFFFFF} - Проставить принятие контрактника в таблице"
                 
    sampShowDialog(1337, "{00FA9A}checklogs help", text, "Закрыть", "", 0)
end