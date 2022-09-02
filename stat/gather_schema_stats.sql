-- Дополнительно можно выклчить:
-- пользовательские таблицы (постоянные и всякие temp, bckp и тд)
-- GTT
-- materialized view log
-- монжо дополнительно установить prefs (incremental, degree и тд)

-- выключить определенные таблицы из общего сбора статистики
begin
    for i in (select owner, table_name from dba_tables where owner = 'A4M' and table_name like 'TTX$%' or table_name like 'TDS$%')
    loop
        dbms_stats.lock_table_stats(i.owner, i.table_name);
    end loop;
end;
/

-- выполнить сбор статистики по схеме с дефолтными значениями
begin
    dbms_stats.gather_schema_stats(ownname => 'A4M', cascade => true); 
end;
/

-- включить выключенные ранее таблицы в общий сбор статистики
begin
    for i in (select owner, table_name from dba_tables where owner = 'A4M' and table_name like 'TTX$%' or table_name like 'TDS$%')
    loop
        dbms_stats.unlock_table_stats (i.owner, i.table_name);
    end loop;
end;
/

-- проверить есть ли таблицы с залоченным сбором статистики
select * from user_tab_statistics where stattype_locked is not null;

-- мониторить сбор статистики по схеме можно в v$session_longops
-- смотрим на time_remaining, elapsed_time, message
-- sql_id в этом случае является top_level_sql_id в v$active_session_history
select * from v$session_longops where opname = 'Gather Schema Statistics';

-- посмотреть, что сейчас обрабатывается
select * from v$session_longops 
where (sid, serial#, sql_id) in 
    (select session_id, session_serial#, sql_id from v$active_session_history where top_level_sql_id in
        (select sql_id from v$session_longops where opname = 'Gather Schema Statistics'))
    and time_remaining > 0;
