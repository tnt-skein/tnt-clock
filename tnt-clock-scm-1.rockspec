rockspec_format = '3.0'

package = 'tnt-clock'
version = 'scm-1'

source = {
    url = 'git+https://github.com/tnt-skein/tnt-clock.git',
    branch = 'main',
}

description = {
    summary = 'Часы и пауза, пригодные к подмене: длительность, срок и дата',
    detailed = [[
        Модуль, меряющий время, не должен обращаться к ядру напрямую:
        тогда проверка минутного ожидания занимает минуту. Время берётся
        из набора подменяемых средств, а обёртки для этого набора у всех
        одинаковы — они собраны здесь.

        Стенные часы (realtime) — для отметок в отчётах и журналах.
        Монотонных двое, и путать их нельзя. monotonic — настоящие часы:
        ими меряют длительность и ими же отмечают срок в миг вызова.
        fiber.clock обновляется только на обороте цикла событий, и работа
        без уступки по нему занимает ноль. scheduler_now — это и есть
        fiber.clock, база остатка срока, который уходит в сон или ожидание:
        fiber.sleep и cond:wait отсчитывают срок от него, и остаток,
        посчитанный по нему, кончается ровно в срок. monotonic64 —
        наносекунды целым числом для метрик. sleep — пауза файбера.

        Зависимостей нет: только `clock` и `fiber` из Tarantool. Покрытие
        строк и убитых мутантов — 100 %.
    ]],
    homepage = 'https://github.com/tnt-skein/tnt-clock',
    issues_url = 'https://github.com/tnt-skein/tnt-clock/issues',
    maintainer = 'tnt-skein',
    license = 'MIT',
    labels = { 'tarantool', 'clock', 'time', 'monotonic', 'deadline', 'fiber' },
}

dependencies = {
    'lua >= 5.1',
}

build = {
    type = 'builtin',
    modules = {
        ['tnt.clock'] = 'tnt/clock.lua',
    },
}
