http://opennet.ru/openforum/vsluhforumID3/119898.html?n=PnD#189
** Use something like translate.google.com to translate from russian.
The following advises are plain enough to understand.

> 1. Вы каждый раз выделаете огромный буфер:
> buf := make([]byte, BUF_LEN)

  Мне самому глаза мозолит, но тут по большому счёту референсный кейс: "по-быстрому обслужи пришедшее соединение и форкни то что долгое в отдельный тред". Соответственно, просто переиспользовать в такой схеме не прокатит. Но таки да, make(buf) всё портит. Не сильно заморачиваясь, есть вариант выделить "кольцо" статикой…
* Альтернативно кон. автомат и пул воркеров как в схемах с nginx (и гонять туда данные по каналам? не, лучше сообщения "возьми этот буфер"), но тут это "из пушки по воробьям".

> Если убрать `go` от `serve`, то можно было бы один раз выделить
> этот буфер (просто вне `for`-а) и постоянно его использовать. Если `go`
> нужен. то можно постараться либо изменить serve (перенести функционал), чтобы ему
> не нужен был этот буфер, либо в крайнем случае хотя бы
> просто применить `sync.Pool` для переиспользования буферов. По факту в отдельной рутине
> (`go serve`) достаточно было оставить только ту часть, что с syscall-ами,
> ибо вычислительная часть занимает сильно меньше, что позволило бы сделать один
> статический буфер (и избежать даже `sync.Pool`).
> Есть ощущение, что именно эта строчка и портит вам всю статистику.

Насчёт syscall's — архи-разумная мысль. Обязательно попробую в след. раз. разнести мухи/котлеты.
sync.Pool + "кольцо" буферов — ага. Тогда вообще есть вариант сразу выпустить воркеров "статикой", по одному на буфер. Дальше "семафорить" или блокировкой, или каналы "сделай"/"сделал".

> 2. Что такое `daemon`? Не вижу его в import-ах.

Пакет go-daemon → "daemon".

>[оверквотинг удален]
>  report := fmt.Sprintf("addr=%s\nhost=%s\n", addr.String(), hostname)
>  if overhead {
>   report += "overhead\n"
>  }
> ... и т.п.
> Это всё тоже в некоторых случаях нехило давит и на CPU и
> на GC. Опять же, sync.Pool + strings.Builder (вместо Sprintf).
> Кроме того, преобразование []byte в string делает копию (давит и на CPU
> и на GC). Вы могли вообще без string тут обойтись (см.
> bytes.Builder, вместо strings.Builder).

  Да. Не слишком красиво/привычно (аналогичные "Sprintf()" есть в большинстве ЯП ), зато без дурных копий.

>[оверквотинг удален]
> программу, то с вашей стороны я бы попросил написать unit/integration тест
> для той части кода, что мы хотим оптимизировать. А я со
> своей стороны пообещаю добиться производительности близкой к Сишной без особых костылей.
> Сделать unit/integration тест очень несложно: просто превратите listen_udp в функцию,
> которая принимает этот `pc` извне аргументом типа net.Conn и напишите тест,
> который вызывает эту функцию, посылает туда хотя бы парочку разных пакетов
> и проверяет правильность результата.
> Я добавлю benchmark тест. Сделаю `go test ./ -bench=. -cpuprofile /tmp/cpu.pprof -memprofile
> /tmp/mem.pprof`, глянем на реально слабые места этой программы и исправим ;)
> https://golang.org/pkg/testing/

Да, идею я понял: для бенча нужна точка куда удобно напихать данных.
Соответственно, "хороший тон" делать так "из коробки". Конкретно здесь — вынести начало обработки пакета в новую функцию (? +пенальти на вызов. Или тесты в GO умеют изображать работу net-сокетов?).
Быстро не обещаю т.к. конкретно этот код "сделал-работает-забыл". Или "на досуге потренироваться", или подвернётся что-нибудь более требовательное к качеству.
