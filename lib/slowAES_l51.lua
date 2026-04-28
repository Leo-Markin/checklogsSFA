-- slowAES портирован на Lua 5.1 / LuaJIT (MoonLoader)
-- Оригинал: by VieGG, адаптация битовых операций для bit.*
local bit = require("bit")
local bxor = bit.bxor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local slowAES = {
    aes = {
        keySize = {
            SIZE_128 = 16,
            SIZE_192 = 24,
            SIZE_256 = 32
        },
        sbox = {[0]=99,124,119,123,242,107,111,197,48,1,103,43,254,215,171,118,
                202,130,201,125,250,89,71,240,173,212,162,175,156,164,114,192,
                183,253,147,38,54,63,247,204,52,165,229,241,113,216,49,21,
                4,199,35,195,24,150,5,154,7,18,128,226,235,39,178,117,
                9,131,44,26,27,110,90,160,82,59,214,179,41,227,47,132,
                83,209,0,237,32,252,177,91,106,203,190,57,74,76,88,207,
                208,239,170,251,67,77,51,133,69,249,2,127,80,60,159,168,
                81,163,64,143,146,157,56,245,188,182,218,33,16,255,243,210,
                205,12,19,236,95,151,68,23,196,167,126,61,100,93,25,115,
                96,129,79,220,34,42,144,136,70,238,184,20,222,94,11,219,
                224,50,58,10,73,6,36,92,194,211,172,98,145,149,228,121,
                231,200,55,109,141,213,78,169,108,86,244,234,101,122,174,8,
                186,120,37,46,28,166,180,198,232,221,116,31,75,189,139,138,
                112,62,181,102,72,3,246,14,97,53,87,185,134,193,29,158,
                225,248,152,17,105,217,142,148,155,30,135,233,206,85,40,223,
                140,161,137,13,191,230,66,104,65,153,45,15,176,84,187,22},
        rsbox = {[0]=82,9,106,213,48,54,165,56,191,64,163,158,129,243,215,251,
                 124,227,57,130,155,47,255,135,52,142,67,68,196,222,233,203,
                 84,123,148,50,166,194,35,61,238,76,149,11,66,250,195,78,
                 8,46,161,102,40,217,36,178,118,91,162,73,109,139,209,37,
                 114,248,246,100,134,104,152,22,212,164,92,204,93,101,182,146,
                 108,112,72,80,253,237,185,218,94,21,70,87,167,141,157,132,
                 144,216,171,0,140,188,211,10,247,228,88,5,184,179,69,6,
                 208,44,30,143,202,63,15,2,193,175,189,3,1,19,138,107,
                 58,145,17,65,79,103,220,234,151,242,207,206,240,180,230,115,
                 150,172,116,34,231,173,53,133,226,249,55,232,28,117,223,110,
                 71,241,26,113,29,41,197,137,111,183,98,14,170,24,190,27,
                 252,86,62,75,198,210,121,32,154,219,192,254,120,205,90,244,
                 31,221,168,51,136,7,199,49,177,18,16,89,39,128,236,95,
                 96,81,127,169,25,181,74,13,45,229,122,159,147,201,156,239,
                 160,224,59,77,174,42,245,176,200,235,187,60,131,83,153,97,
                 23,43,4,126,186,119,214,38,225,105,20,99,85,33,12,125},
        rotate = function(i)
            local t = i[1]
            for r = 1, 3 do i[r] = i[r+1] end
            i[4] = t
            return i
        end,
        Rcon = {[0]=141,1,2,4,8,16,32,64,128,27,54,108,216,171,77,154,
                47,94,188,99,198,151,53,106,212,179,125,250,239,197,
                145,57,114,228,211,189,97,194,159,37,74,148,51,102,
                204,131,29,58,116,232,203,141,1,2,4,8,16,32,64,128,
                27,54,108,216,171,77,154,47,94,188,99,198,151,53,106,
                212,179,125,250,239,197,145,57,114,228,211,189,97,194,
                159,37,74,148,51,102,204,131,29,58,116,232,203,141,1,
                2,4,8,16,32,64,128,27,54,108,216,171,77,154,47,94,
                188,99,198,151,53,106,212,179,125,250,239,197,145,57,
                114,228,211,189,97,194,159,37,74,148,51,102,204,131,
                29,58,116,232,203,141,1,2,4,8,16,32,64,128,27,54,
                108,216,171,77,154,47,94,188,99,198,151,53,106,212,
                179,125,250,239,197,145,57,114,228,211,189,97,194,159,
                37,74,148,51,102,204,131,29,58,116,232,203},
        core = function(self, i, t)
            i = self.rotate(i)
            for r = 1, 4 do
                i[r] = self.sbox[i[r]]
            end
            i[1] = bxor(i[1], self.Rcon[t])
            return i
        end,
        expandKey = function(self, i, t)
            local r = 16 * (self:numberOfRounds(t) + 1)
            local o = 0
            local n = 1
            local s = {}
            local e = {}
            for a = 1, r do e[a] = 0 end
            for h = 1, t do e[h] = i[h] end
            o = o + t
            while o < r do
                for u = 1, 4 do s[u] = e[o - 4 + u] end
                if o % t == 0 then
                    s = self:core(s, n)
                    n = n + 1
                end
                if t == self.keySize.SIZE_256 and o % t == 16 then
                    for f = 1, 4 do s[f] = self.sbox[s[f]] end
                end
                for l = 1, 4 do
                    e[o + 1] = bxor(e[o - t + 1], s[l])
                    o = o + 1
                end
            end
            return e
        end,
        addRoundKey = function(self, i, t)
            for r = 1, 16 do
                i[r] = bxor(i[r], t[r])
            end
            return i
        end,
        createRoundKey = function(self, i, t)
            local r = {}
            for o = 1, 4 do
                for n = 1, 4 do
                    r[4*(n-1)+o] = i[t + 4*(o-1) + n]
                end
            end
            return r
        end,
        subBytes = function(self, i, t)
            local box = t and self.rsbox or self.sbox
            for r = 1, 16 do
                i[r] = box[i[r]]
            end
            return i
        end,
        shiftRows = function(self, i, t)
            for r = 0, 3 do
                i = self:shiftRow(i, 4*r+1, r, t)
            end
            return i
        end,
        shiftRow = function(self, i, t, r, o)
            for n = 1, r do
                if o then
                    local s = i[t+3]
                    for e = 3, 1, -1 do i[t+e] = i[t+e-1] end
                    i[t] = s
                else
                    local s = i[t]
                    for e = 0, 2 do i[t+e] = i[t+e+1] end
                    i[t+3] = s
                end
            end
            return i
        end,
        -- ✅ ИСПРАВЛЕНО: ~ → bxor, & → band, << → lshift, >> → rshift
        galois_multiplication = function(self, a, b)
            local p = 0
            local hi_bit_set
            for counter = 1, 8 do
                if band(b, 1) ~= 0 then
                    p = bxor(p, a)
                end
                hi_bit_set = band(a, 0x80) ~= 0
                a = band(lshift(a, 1), 0xFF)
                if hi_bit_set then
                    a = bxor(a, 0x1B)
                end
                b = rshift(b, 1)
            end
            return p
        end,
        mixColumns = function(self, i, t)
            for o = 1, 4 do
                local r = {}
                for n = 1, 4 do r[n] = i[4*(n-1)+o] end
                r = self:mixColumn(r, t)
                for s = 1, 4 do i[4*(s-1)+o] = r[s] end
            end
            return i
        end,
        mixColumn = function(self, i, t)
            local r = t and {14,9,13,11} or {2,1,1,3}
            local o = {}
            for n = 1, 4 do o[n] = i[n] end
            i[1] = bxor(bxor(bxor(self:galois_multiplication(o[1],r[1]), self:galois_multiplication(o[4],r[2])), self:galois_multiplication(o[3],r[3])), self:galois_multiplication(o[2],r[4]))
            i[2] = bxor(bxor(bxor(self:galois_multiplication(o[2],r[1]), self:galois_multiplication(o[1],r[2])), self:galois_multiplication(o[4],r[3])), self:galois_multiplication(o[3],r[4]))
            i[3] = bxor(bxor(bxor(self:galois_multiplication(o[3],r[1]), self:galois_multiplication(o[2],r[2])), self:galois_multiplication(o[1],r[3])), self:galois_multiplication(o[4],r[4]))
            i[4] = bxor(bxor(bxor(self:galois_multiplication(o[4],r[1]), self:galois_multiplication(o[3],r[2])), self:galois_multiplication(o[2],r[3])), self:galois_multiplication(o[1],r[4]))
            return i
        end,
        round = function(self, i, t)
            i = self:subBytes(i, false)
            i = self:shiftRows(i, false)
            i = self:mixColumns(i, false)
            i = self:addRoundKey(i, t)
            return i
        end,
        invRound = function(self, i, t)
            i = self:shiftRows(i, true)
            i = self:subBytes(i, true)
            i = self:addRoundKey(i, t)
            i = self:mixColumns(i, true)
            return i
        end,
        main = function(self, i, t, r)
            i = self:addRoundKey(i, self:createRoundKey(t, 0))
            for o = 1, r-1 do
                i = self:round(i, self:createRoundKey(t, 16*o))
            end
            i = self:subBytes(i, false)
            i = self:shiftRows(i, false)
            i = self:addRoundKey(i, self:createRoundKey(t, 16*r))
            return i
        end,
        invMain = function(self, i, t, r)
            i = self:addRoundKey(i, self:createRoundKey(t, 16*r))
            for o = r-1, 1, -1 do
                i = self:invRound(i, self:createRoundKey(t, 16*o))
            end
            i = self:shiftRows(i, true)
            i = self:subBytes(i, true)
            i = self:addRoundKey(i, self:createRoundKey(t, 0))
            return i
        end,
        numberOfRounds = function(self, i)
            if i == self.keySize.SIZE_128 then return 10
            elseif i == self.keySize.SIZE_192 then return 12
            elseif i == self.keySize.SIZE_256 then return 14
            else return nil end
        end,
        encrypt = function(self, i, t, r)
            local o = {}
            local n = {}
            local s = self:numberOfRounds(r)
            for e = 0, 3 do
                for a = 0, 3 do
                    n[e + 4*a + 1] = i[4*e + a + 1]
                end
            end
            r = self:expandKey(t, r)
            n = self:main(n, r, s)
            for h = 0, 3 do
                for u = 0, 3 do
                    o[4*h + u + 1] = n[h + 4*u + 1]
                end
            end
            return o
        end,
        decrypt = function(self, i, t, r)
            local o = {}
            local n = {}
            local s = self:numberOfRounds(r)
            for e = 0, 3 do
                for a = 0, 3 do
                    n[e + 4*a + 1] = i[4*e + a + 1]
                end
            end
            r = self:expandKey(t, r)
            n = self:invMain(n, r, s)
            for h = 0, 3 do
                for u = 0, 3 do
                    o[4*h + u + 1] = n[h + 4*u + 1]
                end
            end
            return o
        end
    },
    modeOfOperation = {
        OFB = 0,
        CFB = 1,
        CBC = 2
    },
    getBlock = function(self, i, t, r, o)
        if r - t > 16 then r = t + 16 end
        local block = {}
        for idx = t+1, r do
            table.insert(block, i[idx])
        end
        return block
    end,
    encrypt = function(self, i, t, r, o)
        local n = #r
        if #o % 16 ~= 0 then error("iv length must be 128 bits.") end
        local s
        local e = {}
        local a = {}
        local h = {}
        local u = {}
        local f = true
        if t == self.modeOfOperation.CBC then
            self:padBytesIn(i)
        end
        if i ~= nil then
            for l = 0, math.ceil(#i/16)-1 do
                local c = 16*l
                local d = 16*l + 16
                if d > #i then d = #i end
                s = self:getBlock(i, c, d, t)
                if t == self.modeOfOperation.CFB then
                    if f then a = self.aes:encrypt(o, r, n); f = false
                    else a = self.aes:encrypt(e, r, n) end
                    for p = 1, 16 do h[p] = bxor(s[p], a[p]) end
                    for v = 1, d-c do table.insert(u, h[v]) end
                    e = h
                elseif t == self.modeOfOperation.OFB then
                    if f then a = self.aes:encrypt(o, r, n); f = false
                    else a = self.aes:encrypt(e, r, n) end
                    for p = 1, 16 do h[p] = bxor(s[p], a[p]) end
                    for v = 1, d-c do table.insert(u, h[v]) end
                    e = a
                elseif t == self.modeOfOperation.CBC then
                    for p = 1, 16 do
                        e[p] = bxor(s[p], f and o[p] or h[p])
                    end
                    f = false
                    h = self.aes:encrypt(e, r, n)
                    for v = 1, 16 do table.insert(u, h[v]) end
                end
            end
        end
        return u
    end,
    decrypt = function(self, t, r, o, n)
        local s = #o
        if #n % 16 ~= 0 then error("iv length must be 128 bits.") end
        local e
        local a = {}
        local h = {}
        local u = {}
        local f = {}
        local l = true
        if t ~= nil then
            for c = 0, math.ceil(#t/16)-1 do
                local d = 16*c
                local p = 16*c + 16
                if p > #t then p = #t end
                e = self:getBlock(t, d, p, r)
                if r == self.modeOfOperation.CFB then
                    if l then h = self.aes:encrypt(n, o, s); l = false
                    else h = self.aes:encrypt(a, o, s) end
                    for i = 1, 16 do u[i] = bxor(h[i], e[i]) end
                    for v = 1, p-d do table.insert(f, u[v]) end
                    a = e
                elseif r == self.modeOfOperation.OFB then
                    if l then h = self.aes:encrypt(n, o, s); l = false
                    else h = self.aes:encrypt(a, o, s) end
                    for i = 1, 16 do u[i] = bxor(h[i], e[i]) end
                    for v = 1, p-d do table.insert(f, u[v]) end
                    a = h
                elseif r == self.modeOfOperation.CBC then
                    h = self.aes:decrypt(e, o, s)
                    for i = 1, 16 do
                        u[i] = bxor(l and n[i] or a[i], h[i])
                    end
                    l = false
                    for v = 1, p-d do table.insert(f, u[v]) end
                    a = e
                end
            end
            if r == self.modeOfOperation.CBC then
                self:unpadBytesOut(f)
            end
        end
        return f
    end,
    padBytesIn = function(self, i)
        local t = 16 - (#i % 16)
        for r = 1, t do table.insert(i, t) end
    end,
    unpadBytesOut = function(self, i)
        local t = 0
        local r = -1
        if #i > 16 then
            for o = #i, #i-16+1, -1 do
                if i[o] > 16 then break end
                if r == -1 then r = i[o] end
                if i[o] ~= r then t = 0; break end
                t = t + 1
                if t == r then break end
            end
            if t > 0 then
                for _ = 1, t do table.remove(i) end
            end
        end
    end
}

return slowAES