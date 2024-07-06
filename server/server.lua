ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent('ns-achievements:CheckDB', function()
    print("running DB check")
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local cid = Player.identifier
    local Achievements = {}

    MySQL.Async.fetchAll('SELECT * FROM achievements WHERE citizenid = @citizenid', { ['@citizenid'] = cid }, function(result)
        if not result[1] then
            for k,v in pairs(Config.Achievements) do
                Achievements[k] = {
                    isCompleted = false,
                    currentValue = 0,
                    valueNeeded = v.valueNeeded,
                }
            end
            MySQL.Async.execute('INSERT INTO achievements (citizenid, myachievements) VALUES (@citizenid, @myachievements)', {
                ['@citizenid'] = cid,
                ['@myachievements'] = json.encode(Achievements),
            })
        else 
            local CurrentAchievements = json.decode(result[1].myachievements) 
            for k,v in pairs(Config.Achievements) do
                if CurrentAchievements[k] == nil then
                    CurrentAchievements[k] = {
                        isCompleted = false,
                        currentValue = 0,
                        valueNeeded = v.valueNeeded,
                    }
                end
            end
            for k,v in pairs(CurrentAchievements) do
                if Config.Achievements[k].valueNeeded ~= v.valueNeeded then
                    CurrentAchievements[k].valueNeeded = Config.Achievements[k].valueNeeded
                end
            end
            local final = json.encode(CurrentAchievements)
            MySQL.Async.execute('UPDATE achievements SET myachievements = @myachievements WHERE citizenid = @citizenid', { 
                ['@myachievements'] = final, 
                ['@citizenid'] = cid 
            })   
        end
    end)
end)

ESX.RegisterServerCallback('ns-achievements:GetAchievements', function(source, cb)
    local calltable = nil
    local Player = ESX.GetPlayerFromId(source)
    local cid = Player.identifier

    MySQL.Async.fetchAll('SELECT * FROM achievements WHERE citizenid = @citizenid', { ['@citizenid'] = cid }, function(result)
        if result[1] then
            calltable = json.decode(result[1].myachievements)
            local checktable = Config.Achievements
            for k,v in pairs(calltable) do
                if v.isCompleted then
                    print("isCompleted")
                    checktable[k].isCompleted = true
                else
                    print("notCompleted")
                    checktable[k].currentValue = v.currentValue
                end
            end
            cb(checktable)
        else
            cb(nil)
        end    
    end)
end)

RegisterNetEvent('ns-achievements:AddValue', function(code, value)
    local src = source
    AddValue(src, code, value)
end)

function AddValue(src, code, value)
    if not Config.Achievements[code] then print("error wrong code") return end
    if not value then value = 1 end
    local valueNeeded = Config.Achievements[code].valueNeeded
    local Player = ESX.GetPlayerFromId(src)
    local cid = Player.identifier

    MySQL.Async.fetchAll('SELECT * FROM achievements WHERE citizenid = @citizenid', { ['@citizenid'] = cid }, function(result)
        if result[1] then
            calltable = json.decode(result[1].myachievements)
            local checktable = Config.Achievements
            if calltable[code] ~= nil then
                if calltable[code].isCompleted == true then print("already completed") return end
                if calltable[code].currentValue + value >= calltable[code].valueNeeded then
                    EarnAchievement(src, code)
                else
                    calltable[code].currentValue = calltable[code].currentValue + value
                    local final = json.encode(calltable)
                    MySQL.Async.execute('UPDATE achievements SET myachievements = @myachievements WHERE citizenid = @citizenid', { 
                        ['@myachievements'] = final, 
                        ['@citizenid'] = cid 
                    }) 
                end
            else
                print("error calltable is nil")
            end
        end 
    end)
end

exports('AddValue', AddValue)

RegisterNetEvent('ns-achievements:AddGroupValue', function(group, value)
    local src = source
    AddGroupValue(src, group, value)
end)

function AddGroupValue(src, group, value)
    if not value then value = 1 end
    local Player = ESX.GetPlayerFromId(src)
    local cid = Player.identifier

    MySQL.Async.fetchAll('SELECT * FROM achievements WHERE citizenid = @citizenid', { ['@citizenid'] = cid }, function(result)
        if result[1] then
            local calltable = json.decode(result[1].myachievements)
            local changes = false

            for k, v in pairs(Config.Achievements) do
                if v.group == group then
                    local achievement = calltable[k]
                    if achievement and not achievement.isCompleted then
                        if achievement.currentValue + value >= v.valueNeeded then
                            achievement.isCompleted = true
                            TriggerClientEvent('ns-achievements:AchievementEarned', src, k)
                            changes = true
                        else
                            achievement.currentValue = achievement.currentValue + value
                            changes = true
                        end
                    end
                end
            end

            if changes then
                local final = json.encode(calltable)
                MySQL.Async.execute('UPDATE achievements SET myachievements = @myachievements WHERE citizenid = @citizenid', { 
                    ['@myachievements'] = final, 
                    ['@citizenid'] = cid 
                }) 
            end
        end
    end)
end

exports('AddGroupValue', AddGroupValue)

function EarnAchievement(src, code)
    local Player = ESX.GetPlayerFromId(src)
    local cid = Player.identifier
    MySQL.Async.fetchAll('SELECT * FROM achievements WHERE citizenid = @citizenid', { ['@citizenid'] = cid }, function(result)
        if result[1] then
            calltable = json.decode(result[1].myachievements)
            local checktable = Config.Achievements
            if calltable[code] ~= nil then
                if calltable[code].isCompleted == true then print("already completed") return end
                calltable[code].isCompleted = true
                TriggerClientEvent('ns-achievements:AchievementEarned', src, code)
                local final = json.encode(calltable)
                MySQL.Async.execute('UPDATE achievements SET myachievements = @myachievements WHERE citizenid = @citizenid', { 
                    ['@myachievements'] = final, 
                    ['@citizenid'] = cid 
                }) 
                -- if checktable.reward ~= nil then
                --     if checktable.reward.type ~= nil and checktable.reward.amount ~= nil then
                --         if checktable.reward.type == 'cash' then
                --             Player.addMoney(checktable.reward.amount)
                --         elseif checktable.reward.type == 'bank' then
                --             Player.addAccountMoney('bank', checktable.reward.amount)
                --         elseif checktable.reward.type == 'item' and checktable.reward.item ~= nil then
                --             Player.addInventoryItem(checktable.reward.item, checktable.reward.amount)
                --         elseif checktable.reward.type == 'other' then
                --             print("YOU NEED TO ADD YOUR CUSTOM EVENT/ ACTION IN SERVER.LUA")
                --         else
                --             print("reward triggered with invalid type")
                --         end
                --     end
                -- end       
            else
                print("error calltable is nil")
            end
        end 
    end)
end
