-- содержит информацию о лимитах ресурсов бд (блокировка, сессиях, процессах и тд.)
-- на момент создания AWR снимка, отмечается количство активных сессий и тд и максимальное количество 
-- dba_hist_resource_limit




-- Количество подключений к БД за день: trunc(sysdate-1)
-- Запускать требуется не раньше 2х часов ночи текущего дня, дабы успели создаться AWR снепшоты.
with snap_list as (
    select 
        trunc(sysdate-1) date_calc, snap_id 
    from dba_hist_snapshot where begin_interval_time > startup_time and begin_interval_time >= trunc(sysdate-1) and end_interval_time < trunc(sysdate)
)
select 
    date_calc, stat_name, sum(value) number_of_logons 
from dba_hist_sysstat 
    inner join snap_list using(snap_id) 
where lower(stat_name) = 'logons current' 
group by date_calc, stat_name;


DATE_CALC           STAT_NAME       NUMBER_OF_LOGONS
------------------- --------------- ----------------
30.05.2023 00:00:00 logons current             11995




-- Время, затраченное на инициализацию подключений (в секундах).
-- Равномерно растущие показатели количества логонов и времени подключения сессии говорят, о стабильности работы БД. 
-- При повышенном времени подключения при снижающемся количестве logon'ов говорит о проблемах с подключением к БД.
with snap_list as (
    select 
        trunc(sysdate-1) date_calc, snap_id 
    from dba_hist_snapshot where begin_interval_time > startup_time and begin_interval_time >= trunc(sysdate-1) and end_interval_time < trunc(sysdate)
)
select 
    date_calc, stat_name, round(sum(value)/1e6) session_connect_time 
from dba_hist_sysstat 
    inner join snap_list using(snap_id) 
where lower(stat_name) = 'session connect time' 
group by date_calc, stat_name;


DATE_CALC           STAT_NAME            SESSION_CONNECT_TIME
------------------- -------------------- --------------------
30.05.2023 00:00:00 session connect time                38709
