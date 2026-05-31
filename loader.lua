if identifyexecutor and identifyexecutor() == "Solara" then
    local old = getrawmetatable
    getrawmetatable = function(obj)
        if obj == _G then
            return nil
        end
        return old(obj)
    end
end

getgenv().SCRIPT_KEY = "KEYLESS"
loadstring(game:HttpGet("https://api.jnkie.com/api/v1/luascripts/public/9e4cc35dac336cec1b07abfc42daa58a021bf0fd50780d1eea5af3beb736bc32/download"))()
