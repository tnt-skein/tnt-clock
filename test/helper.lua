--- Общие средства проверок часов.
---
--- Модуль грузится заново перед каждой проверкой загрузчиком оснастки:
--- он лежит под именем `tnt.clock`, и встроенный `clock` ядра, который
--- модуль берёт сам, загрузка не трогает.
---
--- Работа без уступки — тоже из оснастки: её длительность мерят настоящие
--- часы ядра, а не проверяемые, и работа, которую проверяемые часы сочли
--- бы нулевой, всё равно кончается.
---
--- Исходники читаются с диска, а не через `require`: у Tarantool свой
--- загрузчик `.rocks`, он идёт раньше `package.path` и подсунул бы
--- установленную копию пакета, если она есть. Оснастка в `test/testing/`
--- грузится так же и один раз на процесс: второй экземпляр загрузчика
--- не знал бы, что вытеснил первый, и не вернул бы вытесненное на место.

local fio = require('fio')

--- Модули оснастки в порядке зависимостей.
local TESTING = {
    { name = 'tnt.testing.sources', path = 'test/testing/sources.lua' },
    { name = 'tnt.testing.clock', path = 'test/testing/clock.lua' },
}

for _, module in ipairs(TESTING) do
    if package.loaded[module.name] == nil then
        local chunk, failure = loadfile(fio.abspath(module.path))

        if chunk == nil then
            error(('оснастка %s не читается: %s'):format(module.name, tostring(failure)))
        end

        package.loaded[module.name] = chunk()
    end
end

--- Оснастка проверок под теми именами, что зовёт помощник.
local testing = {
    load_sources = package.loaded['tnt.testing.sources'].load,
    unload_sources = package.loaded['tnt.testing.sources'].unload,
    work_without_yielding = package.loaded['tnt.testing.clock'].work_without_yielding,
}

local helper = {}

--- Модули пакета.
helper.MODULES = { { name = 'tnt.clock', path = 'tnt/clock.lua' } }

--- Свежий экземпляр пакета из исходников.
---@return any
function helper.load()
    return testing.load_sources(helper.MODULES, 'tnt.clock')
end

--- Убирает загруженный экземпляр.
function helper.unload()
    testing.unload_sources(helper.MODULES)
end

--- Занимает файбер работой, не уступая управления.
helper.work_without_yielding = testing.work_without_yielding

return helper
