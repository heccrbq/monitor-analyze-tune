-- #1
select sql_id, sql_text from dba_hist_sqltext where sql_id = '5fazzyb6hs9g6';

-- #2
with jbprfx as (
    select 
        regexp_substr(job_name, '^TASK\$_\d+') job_prefix, count(distinct job_name) job_count, 
        cast(min(req_start_date) as date) job_start_date, 
        min(run_duration) min_duration, max(run_duration) max_duration,
        min(cpu_used) min_cpu_used, max(cpu_used) max_cpu_used
    from dba_scheduler_job_run_details 
    where regexp_like (job_name, '^TASK\$_\d+_\d+$')
    group by regexp_substr(job_name, '^TASK\$_\d+')
)

select 
    jb.*, pet.task_name, pet.sql_stmt 
from jbprfx jb 
    left join dba_parallel_execute_tasks pet 
    on pet.job_prefix = jb.job_prefix
order by trunc(jb.job_start_date) desc, max_cpu_used desc;

-- #3
with jbprfx as (
    select 
        regexp_substr(job_name, '^TASK\$_\d+') job_prefix,
        to_number(substr(session_id, 1, instr(session_id, ',')-1)) sid, 
        to_number(substr(session_id, instr(session_id, ',')+1)) serial#,
--        req_start_date,
--        req_start_date + run_duration,
        (select snap_id from dba_hist_snapshot sn where req_start_date between sn.begin_interval_time and sn.end_interval_time) start_snap_id,
        (select snap_id from dba_hist_snapshot sn where req_start_date+run_duration between sn.begin_interval_time and sn.end_interval_time) stop_snap_id
    from dba_scheduler_job_run_details 
    where regexp_like (job_name, '^TASK\$_\d+_\d+$')
        and job_name like 'TASK$_295942%'
--        and trunc(req_start_date) = date'2023-01-26'
)

select 
    jb.job_prefix, ash.sql_id, min(jb.start_snap_id) || '-' ||  max(jb.stop_snap_id) range_snap, 
    count(distinct sql_exec_id || to_char(sql_exec_start, 'yyyymmddhh24:mi:ss')) unq_run, count(1) rowcount, sum(tm_delta_db_time) db_time, sum(tm_delta_cpu_time) cpu_time
from jbprfx jb left join dba_hist_active_sess_history ash 
    on ash.snap_id between jb.start_snap_id and jb.stop_snap_id 
    and ash.session_id = jb.sid 
    and ash.session_serial# = jb.serial#
group by grouping sets ((jb.job_prefix, ash.sql_id), null)
order by job_prefix, rowcount desc;

-- #4
with source as (
    select '4423c6j0udsqj' sql_id, trunc(sysdate) - 30 btime, trunc(sysdate) + 1 etime from dual
 )
select 
--    (select trim(dbms_lob.substr(t.sql_text, 4000)) from dba_hist_sqltext t where s.sql_id = t.sql_id) AS text,
--    s.sql_id AS sqlid,
    s.plan_hash_value hv,
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
from dba_hist_sqlstat s,
    dba_hist_snapshot w,
    source src
where s.snap_id = w.snap_id
    and s.instance_number = w.instance_number
    and s.sql_id = src.sql_id
    and w.begin_interval_time between src.btime and src.etime
group by trunc(w.begin_interval_time),
    s.sql_id
    ,s.plan_hash_value
order by tl desc;

-- #5
select * from table(dbms_xplan.display_awr('4423c6j0udsqj',1997761311));
