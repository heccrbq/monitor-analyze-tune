set serveroutput on
set feedback on
set verify off
set pages 500
set timing off



define sql_id="gdczupf8bs9hx"



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#1. COMMON SQL INFO'                     SKIP 1-
       LEFT ========================================= SKIP 1 
/
col command_name for a12
with source as (
    select '&sql_id' sql_id from dual
)
select command_name, s.sql_id, 
    (select count(distinct st.plan_hash_value) from dba_hist_sqlstat st where st.sql_id = s.sql_id) plan_loaded,
    sql_text
from source s
    join dba_hist_sqltext t on t.sql_id = s.sql_id
    join dba_hist_sqlcommand_name using (command_type);



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#2. HIST  STATISTICS  PER  DAY'          SKIP 1-
       LEFT ========================================= SKIP 1 
/
col cn for a10
with source as (
    select '&sql_id' sql_id, trunc(sysdate) - 30 btime, sysdate + 1 etime from dual
 )
select 
    s.sql_id AS sqlid,
    s.plan_hash_value phv,
    trunc(w.begin_interval_time) AS tl,
    sum(s.executions_delta) AS e,
    round(sum(s.elapsed_time_delta)     / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS ela,
    round(sum(s.cpu_time_delta)         / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS cpu,
    round(sum(s.iowait_delta)           / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS io,
    round(sum(s.ccwait_delta)           / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS cc,
    round(sum(s.apwait_delta)           / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS app,
    round(sum(s.plsexec_time_delta)     / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS plsql,
    round(sum(s.javexec_time_delta)     / greatest(sum(s.executions_delta), 1) / 1e6, 4) AS java,
    round(sum(s.disk_reads_delta)       / greatest(sum(s.executions_delta), 1)) AS disk,
    round(sum(s.buffer_gets_delta)      / greatest(sum(s.executions_delta), 1)) AS lio,
    round(sum(s.rows_processed_delta)   / greatest(sum(s.executions_delta), 1)) AS r,
    round(sum(s.parse_calls_delta)      / greatest(sum(s.executions_delta), 1)) AS pc,
    round(sum(s.px_servers_execs_delta) / greatest(sum(s.executions_delta), 1)) AS px
from source src,
    dba_hist_sqlstat s,
    dba_hist_snapshot w
where s.snap_id = w.snap_id
    and s.instance_number = w.instance_number
    and s.sql_id = src.sql_id
    and w.begin_interval_time between src.btime and src.etime
group by trunc(w.begin_interval_time),
    s.sql_id,
    s.plan_hash_value
order by tl desc, ela * greatest(e,1) desc nulls last;



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#3. HIST  STATISTICS  PER  EXECUTION'    SKIP 1-
       LEFT ========================================= SKIP 1 
/
col sid_serial for a15
col snap_range for a20
with source as (
    select '&sql_id' sql_id, trunc(sysdate) - 30 btime, sysdate etime from dual
 )
select
    ash.sql_id,
    ash.sql_plan_hash_value plan_hash_value,
    ash.sql_exec_id, 
    ash.session_id || ',' || ash.session_serial# sid_serial, 
    min(w.snap_id) || ' - ' || max(w.snap_id) snap_range,
    ash.sql_exec_start, 
    cast(max(ash.sample_time) as date) sql_exec_stop, 
--    round((cast(max(ash.sample_time) as date) - ash.sql_exec_start) * 86400) sql_exec_diff,
    round(sum(ash.tm_delta_db_time)/1e6, 2) db_time, 
    round(sum(ash.tm_delta_cpu_time)/1e6, 2) cpu_time, 
    round(sum(ash.delta_read_io_bytes)/1024/1024) read,
    round(sum(ash.delta_write_io_bytes)/1024/1024) write,
    -- in flags --
    count(1) wait_count,
    count(nullif(ash.in_parse, 'N')) parse,
    count(nullif(ash.in_hard_parse, 'N')) hard_parse,
    count(nullif(ash.in_sql_execution, 'N')) sql,
    count(nullif(ash.in_plsql_execution, 'N')) plsql,
    count(nullif(ash.in_java_execution, 'N')) java,
    count(nullif(ash.in_cursor_close, 'N')) cursor_close
from source s
    join dba_hist_active_sess_history ash on ash.sql_id = s.sql_id
    join dba_hist_snapshot w on w.instance_number = ash.instance_number
                            and w.dbid = ash.dbid
                            and w.snap_id = ash.snap_id
                            and w.begin_interval_time between s.btime and s.etime
group by ash.sql_id,
    ash.sql_plan_hash_value,
    ash.sql_exec_id,
    ash.session_id,
    ash.session_serial#,
    ash.sql_exec_start
order by sql_exec_start desc nulls last;



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#4. MONITOR  STATISTICS  PER  EXECUTION' SKIP 1-
       LEFT ========================================= SKIP 1 
/
with source as (
    select '&sql_id' sql_id from dual
)
select 
    status, sid, sql_exec_id, sql_exec_start, sql_id, sql_plan_hash_value, 
    output_rows, numtodsinterval((last_refresh_time - sql_exec_start),'day') ela
from source natural join v$sql_plan_monitor sm
where plan_line_id = 0
order by sql_id, sql_exec_start desc;



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#5. SQL  PLAN  STATISTICS  :  SQLSTATS'  SKIP 1-
       LEFT ========================================= SKIP 1 
/
with source as (
    select '&sql_id' sql_id, trunc(sysdate) - 30 btime, sysdate etime from dual
)

select
    st.sql_id, st.plan_hash_value,
    sum(st.executions_delta) AS e,
    round(sum(st.elapsed_time_delta) / greatest(sum(st.executions_delta), 1) / 1e6, 4) AS ela
from source s
    join dba_hist_snapshot w on w.begin_interval_time between s.btime and s.etime
    join dba_hist_sqlstat st on st.snap_id = w.snap_id
                            and st.dbid = w.dbid
                            and st.instance_number = w.instance_number 
                            and st.sql_id = s.sql_id
group by st.sql_id, st.plan_hash_value;



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#6. SQL  PLAN  STATISTICS  :  HIST ASH'  SKIP 1-
       LEFT ========================================= SKIP 1 
/
with source as (
    select '&sql_id' sql_id, trunc(sysdate) - 30 btime, sysdate etime from dual
),
stat as (
    select
        st.snap_id, st.sql_id, st.plan_hash_value, st.instance_number
    from source s
        join dba_hist_snapshot w on w.begin_interval_time between s.btime and s.etime
        join dba_hist_sqlstat st on st.snap_id = w.snap_id
                                and st.dbid = w.dbid
                                and st.instance_number = w.instance_number 
                                and st.sql_id = s.sql_id
)

select 
    sql_id, plan_hash_value, 
    round(avg(db_time)/1e3) avg#, 
    round(stddev(db_time)/1e3) stddev#, 
    round(min(db_time)/1e3) min#, 
    round(max(db_time)/1e3) max#, 
    count(1) sqlexec
from (
    select 
        s.sql_id, s.plan_hash_value,
        sum(ash.tm_delta_db_time) db_time
    from stat s, dba_hist_active_sess_history ash 
    where s.snap_id = ash.snap_id 
        and s.sql_id = ash.sql_id 
        and s.plan_hash_value = ash.sql_plan_hash_value
        and s.instance_number = ash.instance_number 
    group by s.sql_id, s.plan_hash_value, sql_exec_id,sql_exec_start)
group by sql_id, plan_hash_value;



TTITLE LEFT ========================================= SKIP 1 -
       LEFT '#7. LIST  OF  SQL  EXECUTION  PLANS'     SKIP 1-
       LEFT ========================================= SKIP 1 
/
select * from table(dbms_xplan.display_awr('&sql_id'));
