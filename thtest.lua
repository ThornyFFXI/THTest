addon.name      = 'THTest';
addon.author    = 'Thorny';
addon.version   = '1.00';
addon.desc      = 'Test Addon';
addon.link      = 'https://github.com/ThornyFFXI/';

require('common');
local fontObj;
local fonts = require('fonts');
local fontSettings = T{
    visible = true,
    font_family = 'Arial',
    font_height = 15,
    color = 0xFFFFFFFF,
    color_outline  = 0xFF000000,
    position_x = 100,
    position_y = 100,
    draw_flags = FontDrawFlags.Outlined,
    background = T{
        visible = true,
        color = 0x80000000,
    }
};

local currentTarget = {};
local globalProcCount = T{};
local currentPlayerTH = 21;

local filePath;
local backupPath;

ashita.events.register('load', 'load_cb', function ()
    fontObj = fonts.new(fontSettings);
    local time = os.date('*t');
    local folderName = string.format('%slogs/thtest', AshitaCore:GetInstallPath());
    ashita.fs.create_dir(folderName);
    local fileName = ('%04d%02d%02d_%02d%02d%02d.csv'):format(time.year, time.month, time.day, time.hour, time.min, time.sec);
    filePath = string.format('%s/%s', folderName, fileName);
    fileName = ('%04d%02d%02d_%02d%02d%02d_missed.csv'):format(time.year, time.month, time.day, time.hour, time.min, time.sec);
    backupPath =string.format('%s/%s', folderName, fileName);
    if (not ashita.fs.exists(filePath)) then
        local file = io.open(filePath, 'w');
        file:write('"Timestamp","Mob TH Level","Player TH Level","Proc Index","Proc Crit","First Hit Crit"\n');
        file:close();
    end
    if (not ashita.fs.exists(backupPath)) then
        local file = io.open(backupPath, 'w');
        file:write('"Timestamp","Mob TH Level","Player TH Level","Proc Index","Proc Crit","First Hit Crit"\n');
        file:close();
    end
end);


local function ParseActionPacket(packet)
    local bitOffset;
    local function UnpackBits(length)
        local value = ashita.bits.unpack_be(packet, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local parsedActionPacket = T{};
    bitOffset = 40;
    parsedActionPacket.UserId = UnpackBits(32);
    local targetCount = UnpackBits(6);
    --Unknown 4 bits
    bitOffset = bitOffset + 4;
    parsedActionPacket.Type = UnpackBits(4);
    parsedActionPacket.Id = UnpackBits(32);
    --Unknown 32 bits
    bitOffset = bitOffset + 32;

    parsedActionPacket.Targets = T{};
    for i = 1,targetCount do
        local target = T{};
        target.Id = UnpackBits(32);
        local actionCount = UnpackBits(4);
        target.Actions = T{};
        for j = 1,actionCount do
            local action = {};
            action.Reaction = UnpackBits(5);
            action.Animation = UnpackBits(12);
            action.SpecialEffect = UnpackBits(7);
            action.Knockback = UnpackBits(3);
            action.Param = UnpackBits(17);
            action.Message = UnpackBits(10);
            action.Flags = UnpackBits(31);

            local hasAdditionalEffect = (UnpackBits(1) == 1);
            if hasAdditionalEffect then
                local additionalEffect = {};
                additionalEffect.Damage = UnpackBits(10);
                additionalEffect.Param = UnpackBits(17);
                additionalEffect.Message = UnpackBits(10);
                action.AdditionalEffect = additionalEffect;
            end

            local hasSpikesEffect = (UnpackBits(1) == 1);
            if hasSpikesEffect then
                local spikesEffect = {};
                spikesEffect.Damage = UnpackBits(10);
                spikesEffect.Param = UnpackBits(14);
                spikesEffect.Message = UnpackBits(10);
                action.SpikesEffect = spikesEffect;
            end

            target.Actions:append(action);
        end
        parsedActionPacket.Targets:append(target);
    end

    return parsedActionPacket;
end

local function HandleActionPacket(packet)
    packet = ParseActionPacket(packet);
    if (packet.UserId == AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)) then
        if (packet.Type == 1) then
            local target = packet.Targets[1];
            if target then
                local targetId = target.Id;
                if (targetId ~= currentTarget.Id) then
                    currentTarget = {
                        Id = targetId,
                        TH = math.min(currentPlayerTH, 8),
                        ProcCount = T{},
                        Name = 'Unknown',
                    };
                    for i = 0,0x400 do
                        if (AshitaCore:GetMemoryManager():GetEntity():GetServerId(i) == targetId) then
                            currentTarget.Name = AshitaCore:GetMemoryManager():GetEntity():GetName(i);
                            currentTarget.Index = i;
                        end
                    end
                end

                local currentTH = currentTarget.TH;
                local localProcCount = currentTarget.ProcCount;                
                if (localProcCount[currentTH] == nil) then
                    localProcCount[currentTH] = { HitCount=1, ProcCount=0 };
                else
                    localProcCount[currentTH].HitCount = localProcCount[currentTH].HitCount + 1;
                end

                if (globalProcCount[currentTH] == nil) then
                    globalProcCount[currentTH] = { HitCount=1, ProcCount=0 };
                else
                    globalProcCount[currentTH].HitCount = globalProcCount[currentTH].HitCount + 1;
                end

                local procIndex = 0;
                local wasCrit = T{};
                for index,action in ipairs(target.Actions) do
                    wasCrit[index] = (action.Message == 67);
                    local addEffect = action.AdditionalEffect
                    if (addEffect) then
                        if (addEffect.Message == 603) then
                            procIndex = index;
                            currentTarget.TH = addEffect.Param;
                            localProcCount[currentTH].ProcCount = localProcCount[currentTH].ProcCount + 1;
                            globalProcCount[currentTH].ProcCount = globalProcCount[currentTH].ProcCount + 1;
                        end
                    end
                end

                local procCrit = 0;
                if (procIndex ~= 0) then
                    procCrit = (wasCrit[procIndex] and 1 or 0);
                end

                local output = string.format('%u,%u,%u,%u,%u,%u\n',
                    os.time(),
                    currentTH,
                    currentPlayerTH,
                    procIndex,
                    procCrit,
                    wasCrit[1] and 1 or 0);

                local file = io.open(filePath, 'a');
                if (file) then
                    file:write(output);
                    file:close();
                else
                    file = io.open(backupPath, 'a');
                    if file then
                        file:write(output);
                        file:close();
                    else
                        print(string.format('Failed to open file and backup file.  Data Point:%s', output));
                    end
                end
            end
        end
    end
end

local usedSequences = T{};
local newChunk = true;
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if not newChunk then
        return;
    end
    
    newChunk = false;
    local offset = 0;
    local newSequences = T{};
    while (offset < e.chunk_size) do
        local id    = ashita.bits.unpack_be(e.chunk_data_raw, offset, 0, 9);
        local size  = ashita.bits.unpack_be(e.chunk_data_raw, offset, 9, 7) * 4;
        local sequence = ashita.bits.unpack_be(e.chunk_data_raw, offset, 16, 16);
        if (not newSequences:contains(sequence)) then
            newSequences:append(sequence);
        end
        if (not usedSequences:contains(sequence)) and (id == 0x28) then
            HandleActionPacket(struct.unpack('c' .. size, e.chunk_data, offset + 1):totable());
        end
        offset = offset + size;
    end
    usedSequences = newSequences;
end);

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    newChunk = true;
    local textBlock = 'Current Target: ';
    if (currentTarget.Id ~= nil) then
        textBlock = textBlock .. string.format('%s[%u]\n', currentTarget.Name, currentTarget.Id);
        local procs = currentTarget.ProcCount;
        for i = 0,14 do
            local data = procs[i];
            if data then
                local percentString = '(0.00%)';
                if (data.ProcCount > 0) then
                    percentString = string.format('(%.02f%%)', (data.ProcCount / data.HitCount) * 100);
                end
                textBlock = textBlock .. string.format('TH%u->%u: %u/%u %s\n', i, i+1, data.ProcCount, data.HitCount, percentString);
            end
        end
    else
        textBlock = textBlock .. '\n';
    end

    textBlock = textBlock .. '\nSession Stats\n';
    local sumHits = 0;
    local sumProcs = 0;
    local procs = globalProcCount;
    for i = 0,14 do
        local data = procs[i];
        if data then
            local percentString = '(0.00%)';
            if (data.ProcCount > 0) then
                percentString = string.format('(%.02f%%)', (data.ProcCount / data.HitCount) * 100);
            end
            textBlock = textBlock .. string.format('TH%u->%u: %u/%u %s\n', i, i+1, data.ProcCount, data.HitCount, percentString);
            sumHits = sumHits + data.HitCount;
            sumProcs = sumProcs + data.ProcCount;
        end
    end
    local percentString = '(0.00%)';
    if (sumProcs > 0) then
        percentString = string.format('(%.02f%%)', (sumProcs / sumHits) * 100);
    end
    textBlock = textBlock .. string.format('All: %u/%u %s', sumProcs, sumHits, percentString);

    if (currentTarget.Index ~= nil) then
        if (AshitaCore:GetMemoryManager():GetEntity():GetHPPercent(currentTarget.Index) == 0) then
            currentTarget.TH = math.min(currentPlayerTH, 8);
        elseif (AshitaCore:GetMemoryManager():GetEntity():GetStatus(currentTarget.Index) == 0) then
            currentTarget.TH = math.min(currentPlayerTH, 8);
        end
    end

    fontObj.text = textBlock;
end);

ashita.events.register('unload', 'unload_cb', function ()
    if (fontObj ~= nil) then
        fontObj:destroy();
        fontObj = nil;
    end
end);