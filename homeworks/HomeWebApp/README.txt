В файле config (без расширения) содержится JSON с некоторыми параметрами для создания базы.
В файле schema.sql содержится JSON : массив команд для создания базы.
Файл xmlquery.pl я использовал для тестирования XML-RPC. Из его кода можно определить, правильно ли я понял, что от меня требовалось.
Используется memcached, слушающий порт 11211. Можно изменить в config'е.
Админом является только юзер с ником admin.
