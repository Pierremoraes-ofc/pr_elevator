local languages={'pt-br','en-us','es-es','fr-fr'}
local dictionaries={}
local function flatten(value,prefix,result)
    for key,text in pairs(value) do
        local name=prefix and prefix..'.'..key or key
        if type(text)=='table' then flatten(text,name,result)
        else assert(type(text)=='string' and text~='',name);result[name]=text end
    end
end
for _,language in ipairs(languages) do
    dictionaries[language]={}
    flatten(dofile('locale/'..language..'.lua'),nil,dictionaries[language])
end
local count=0
local function formatTokens(text)
    local result={}
    for token in text:gmatch('%%[%d%.]*[sdif]') do result[#result+1]=token end
    for token in text:gmatch('%%{[^}]+}') do result[#result+1]=token end
    table.sort(result);return table.concat(result,'|')
end
for key,text in pairs(dictionaries['en-us']) do
    count=count+1
    for _,language in ipairs(languages) do
        local translated=assert(dictionaries[language][key],language..' missing '..key)
        assert(formatTokens(text)==formatTokens(translated),language..' placeholders differ: '..key)
    end
end
for _,language in ipairs(languages) do
    for key in pairs(dictionaries[language]) do assert(dictionaries['en-us'][key],'EN missing '..key) end
end
for _,file in ipairs({'client/dui.lua','client/main.lua','client/menu.lua','client/menu_exports.lua',
    'client/settings.lua','server/menu.lua','server/settings.lua','install/install.lua'}) do
    local handle=assert(io.open(file,'r'));local source=handle:read('a');handle:close()
    for key in source:gmatch("lang%(['\"]([^'\"]+)['\"]") do
        for _,language in ipairs(languages) do assert(dictionaries[language][key],file..' '..language..' missing '..key) end
    end
end
print(('PASS: %d locale keys in all four languages, interpolation parity and runtime references'):format(count))
