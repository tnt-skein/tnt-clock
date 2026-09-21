--- Тесты часов. Проверяется то немногое, что у обёрток есть своего:
--- какой именно источник времени взят.
---
--- Двойников здесь нет намеренно. Настоящие часы и отметка цикла событий
--- расходятся только на настоящем ядре — двойник показал бы то, что в него
--- положили, — и перепутанный источник заметен лишь на работе, которая
--- не уступает управления.

local ffi = require('ffi')
local fiber = require('fiber')
local t = require('luatest')

local helper = dofile('test/helper.lua')

local g = t.group('tnt.clock')

--- Сколько длится работа без уступки в проверках, в секундах.
---
--- Заметно дольше разрешения часов и заметно короче среза файбера:
--- ядро предупреждает о файбере, не уступающем полсекунды.
local WORK = 0.02

---@type any
local clock

g.before_each(function()
    clock = helper.load()

    -- Отметка цикла событий обновляется на обороте цикла, и `fiber.yield`
    -- его даёт: без него проверка начиналась бы с отметки, отставшей
    -- на всё, что делалось до неё.
    fiber.yield()
end)

g.after_each(function()
    helper.unload()
end)

g.test_monotonic_moves_forward = function()
    local first = clock.monotonic()

    clock.sleep(0.01)

    t.assert_gt(clock.monotonic(), first)
end

g.test_monotonic_counts_work_that_does_not_yield = function()
    -- Длительность работы без уступки по отметке цикла событий — ноль:
    -- снимок на пустой базе, сборка мусора и разбор ответа выходили бы
    -- мгновенными, сколько бы ни шли.
    local started = clock.monotonic()

    helper.work_without_yielding(WORK)

    t.assert_ge(clock.monotonic() - started, WORK)
end

g.test_scheduler_now_stands_still_until_the_fiber_yields = function()
    local before = clock.scheduler_now()

    helper.work_without_yielding(WORK)

    t.assert_equals(clock.scheduler_now(), before)

    fiber.yield()

    t.assert_gt(clock.scheduler_now(), before)
end

g.test_deadline_on_monotonic_with_the_rest_on_scheduler_now_is_kept_to_the_instant = function()
    -- Работа без уступки и до назначения срока, и после него. Сон
    -- отсчитывает остаток от отметки цикла событий, а та стоит с последней
    -- уступки: остаток, посчитанный от неё же, кончается ровно в срок.
    -- Посчитанный по настоящим часам, он кончился бы раньше на всю работу.
    helper.work_without_yielding(WORK)

    local deadline = clock.monotonic() + 3 * WORK

    helper.work_without_yielding(WORK)
    clock.sleep(deadline - clock.scheduler_now())

    t.assert_ge(clock.monotonic(), deadline)
end

g.test_deadline_marked_on_scheduler_now_is_eaten_by_the_work_before_it = function()
    -- Обратная сторона: отметка цикла стоит с последней уступки, и срок,
    -- отмеченный ею после работы без уступки, наступает раньше, чем
    -- через назначенное время от вызова. Поэтому срок отмечает `monotonic`.
    helper.work_without_yielding(2 * WORK)

    local deadline = clock.scheduler_now() + 3 * WORK
    local called = clock.monotonic()

    clock.sleep(deadline - clock.scheduler_now())

    t.assert_lt(clock.monotonic() - called, 3 * WORK)
end

g.test_scheduler_now_counts_from_the_same_origin_as_monotonic = function()
    -- Сразу после уступки обе базы показывают одно и то же: разница
    -- между ними — только отставание отметки, а не точка отсчёта.
    t.assert_almost_equals(clock.scheduler_now(), clock.monotonic(), WORK)
end

g.test_monotonic64_counts_nanoseconds_of_the_same_clock = function()
    local nanoseconds = clock.monotonic64()

    t.assert_equals(ffi.istype('int64_t', nanoseconds), true)
    t.assert_almost_equals(assert(tonumber(nanoseconds)) / 1e9, clock.monotonic(), WORK)
end

g.test_monotonic_is_not_the_wall_clock = function()
    -- Монотонные часы считают от загрузки машины, стенные — от начала
    -- эпохи: спутать их значит однажды получить срок в полвека.
    t.assert_lt(clock.monotonic(), clock.realtime() / 2)
end

g.test_realtime_shows_the_current_time = function()
    t.assert_almost_equals(clock.realtime(), os.time(), 60)
end

g.test_sleep_waits_the_asked_time = function()
    -- Засечка — по времени планировщика: от него пауза и отсчитывается.
    -- Настоящие часы, прочитанные после последней уступки, уже ушли бы
    -- вперёд, и пауза по ним вышла бы короче на эту разницу.
    local started = clock.scheduler_now()

    clock.sleep(0.05)

    t.assert_ge(clock.scheduler_now() - started, 0.05)
end

g.test_sleep_lets_others_work = function()
    -- Пауза должна отдавать управление, а не держать процесс: иначе один
    -- ждущий модуль останавливает весь узел.
    local worked = false

    fiber.create(function()
        worked = true
    end)

    clock.sleep(0.01)

    t.assert_equals(worked, true)
end
