# Mone Menu

Техкарты бара и кухни: Windows, Android, iOS и браузер.

### iPhone / iPad без компьютера и App Store

Откройте в **Safari** на iPhone: <https://alinaibragimovna120-byte.github.io/mone_menu/>

Чтобы приложение было на экране как обычное: кнопка «Поделиться» → «На экран „Домой“».
Оно откроется во весь экран, без адресной строки. Техкарты и фото хранятся на самом телефоне,
в данных Safari; если очистить историю и данные сайтов, они удалятся (встроенные техкарты
и данные с сервера загрузятся снова).

Веб-версия обновляется сама при каждой отправке изменений в `main`
(один раз нужно включить: Settings → Pages → Source: GitHub Actions).

## Сборка

| Платформа | Команда |
|---|---|
| Windows | `flutter build windows` |
| Android | `flutter build apk` |
| Браузер / iPhone (PWA) | `flutter build web` |
