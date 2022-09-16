-- Дополнительно можно выклчить:
-- пользовательские таблицы (постоянные и всякие temp, bckp и тд)
-- GTT
-- materialized view log
-- монжо дополнительно установить prefs (incremental, degree и тд)

-- #1. Проверяем не было ли залоченной статистики до всех манипуляций. Если есть, то запомнить с последующим восстановлением.
select * from user_tab_statistics where stattype_locked is not null;
	
-- #2. Формируем стартовую дата, от которой будем отталкиваться при сборе статистики в случае прерывания
select timestamp'2022-09-09 12:34:56' /*подставляем время запуска сбора статы*/ from dual;
    
-- #3. Запрос мониторинга какие объекты были залочены, а какие попадут в общий сбор статы
select * from user_tab_statistics where stattype_locked is null and last_analyzed <= timestamp'2022-09-09 12:34:56'; /*подставляем время запуска сбора статы*/

-- #4. Выключить определенные таблицы из общего сбора статистики
begin
    for i in (
        select table_name from user_tables ut 
			join user_tab_statistics uts using(table_name)
				where (uts.last_analyzed >= timestamp'2022-09-09 12:34:56'
					or temporary = 'Y'
					or (table_name) in (select log_table from user_mview_logs)    
					or upper(table_name) like 'TTX$%' 
					or upper(table_name) like 'TDS$%' 
					or upper(table_name) like 'TUP$%'
					or upper(table_name) like '%\_TEST%' escape '\'
					or upper(table_name) like '%\_TEMP%' escape '\' 
					or upper(table_name) like 'TEMP\_%' escape '\' 
					or upper(table_name) like '%\_TMP%' escape '\' 
					or upper(table_name) like 'TMP\_%' escape '\' 
					or upper(table_name) like '%\_OLD%' escape '\')
					and stattype_locked is null
    )
    loop
        dbms_stats.lock_table_stats(user, '"' || i.table_name || '"');
    end loop;
end;
/
    
-- #5. Выполнить сбор статистики по схеме с дефолтными значениями
begin
    dbms_stats.gather_schema_stats(ownname => 'A4M', cascade => true, degree => 8); 
end;
/

-- #6. Включить выключенные ранее таблицы в общий сбор статистики
--     Если на первом шаге были объекты, то исключить их из этого шага
begin
    for i in (select * from user_tab_statistics where stattype_locked is not null)
    loop
        dbms_stats.unlock_table_stats (user, '"' || i.table_name || '"');
    end loop;
end;
/

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
