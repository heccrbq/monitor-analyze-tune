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
        and req_start_date >= (select sysdate - retention - 1 from dba_hist_wr_control)
    group by regexp_substr(job_name, '^TASK\$_\d+')
)

select 
    jb.*, pet.task_name, pet.sql_stmt 
from jbprfx jb 
    left join dba_parallel_execute_tasks pet 
    on pet.job_prefix = jb.job_prefix
order by max_duration desc;

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
        and job_name like 'TASK$_296184%'
--        and trunc(req_start_date) = date'2023-01-26'
)

select 
    jb.job_prefix, ash.sql_id, min(jb.start_snap_id) || '-' ||  max(jb.stop_snap_id) range_snap, 
    count(distinct sql_exec_id || to_char(sql_exec_start, 'yyyymmddhh24:mi:ss')) unq_run, count(1) rowcount, 
    round(sum(tm_delta_db_time)/1e6) db_time, round(sum(tm_delta_cpu_time)/1e6) cpu_time
from jbprfx jb left join dba_hist_active_sess_history ash 
    on ash.snap_id between jb.start_snap_id and jb.stop_snap_id 
    and ash.session_id = jb.sid 
    and ash.session_serial# = jb.serial#
group by grouping sets ((jb.job_prefix, ash.sql_id), null)
order by job_prefix, rowcount desc;



select * from dba_hist_sqltext where sql_id = '83cgp9nfu5f3n';
select * from table(dbms_xplan.display_awr('bzbnu7nbkhbkp'));



-- #4
with source as (
    select '83cgp9nfu5f3n' sql_id, trunc(sysdate) - 30 btime, trunc(sysdate) + 1 etime from dual
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


 with source as (
    select 'A4M' index_owner, sys.odcivarchar2list('SYS_C004457163 ') index_list from dual
)
select 
    i.owner index_owner, 
    i.index_name, 
--    i.table_owner, 
--    i.table_name, 
    i.partitioned,
    i.num_rows, 
    i.distinct_keys,
    ca.avg_row_len, 
    i.blevel, 
    i.leaf_blocks, 
--    i.avg_leaf_blocks_per_key,
--    i.avg_data_blocks_per_key,    
    round(s.bytes/1024/1024, 3) allocated_for_segment_mb,
    round(i.num_rows * ca.avg_row_len / 1024 / 1024, 3) used_by_data_mb,
    -- 12 = 10 bytes for rowid + 2 bytes for the index row header
    round((i.num_rows * 12 + ca.avg_rowset_len * (1 + i.pct_free/100))/ 1024 / 1024, 3) estimated_index_size_mb,
    round((i.num_rows * 12 + ca.avg_rowset_len * (1 + i.pct_free/100)) / s.bytes * 100, 2) pct_used
from dba_indexes i
    join dba_segments s on s.owner = i.owner and s.segment_name = i.index_name
    outer apply (
        select 
            sum(tcs.avg_col_len) avg_row_len,
            sum((ins.num_rows - tcs.num_nulls) * tcs.avg_col_len) avg_rowset_len            
        from dba_tables t 
            join dba_tab_col_statistics tcs on tcs.owner = t.owner and tcs.table_name = t.table_name
            join dba_ind_columns ic on ic.index_owner = i.owner and ic.index_name = i.index_name and tcs.column_name = ic.column_name
            join dba_ind_statistics ins on ins.owner = ic.index_owner and ins.index_name = ic.index_name
        where t.table_name = i.table_name and t.owner = i.table_owner
    ) ca
where (i.owner, i.index_name) in (select /*+dynamic_sampling(3)*/ s.index_owner, column_value from source s, table(s.index_list) t)
order by pct_used;



with source as (
    select 'A4M' index_owner, interval'12'month depth from dual
),
--index_list_out_of_plan(index_owner, index_name) as (
--    -- индекс не был найден в dba_hist_sql_plan и в v$sql_plan
--    select 
--        owner, object_name 
--    from (
--        select do.owner, do.object_name, sp.sql_id from dba_objects do 
--            left join dba_hist_sql_plan sp on sp.object# = do.object_id where do.object_type = 'INDEX' and do.owner = (select index_owner from source)
--        union all
--        select do.owner, do.object_name, sp.sql_id from dba_objects do 
--            left join gv$sql_plan sp on sp.object# = do.object_id where do.object_type = 'INDEX' and do.owner = (select index_owner from source)
--    )
--    group by owner, object_name 
--    having max(sql_id) is null
--),
index_list_tab_space as (
    -- добавляем к индексам инфу из таблицы и сегмента
    select
        di.owner index_owner, di.index_name, di.uniqueness, 
        dt.owner table_owner, dt.table_name, dt.last_analyzed, dt.monitoring,
        round(sum(bytes)/1024/1024, 3) index_total_mb
    from /*index_list_out_of_plan iloop
        inner join */dba_indexes di --on di.owner = iloop.index_owner and di.index_name = iloop.index_name
        inner join dba_tables dt on dt.owner = di.table_owner and dt.table_name = di.table_name
        inner join dba_segments ds on ds.owner = di.owner and ds.segment_name = di.index_name
    where di.table_name = 'UBRR_CB_TRANSACTIONS'
--    where dt.table_name not like 'TTX$%' and dt.table_name not like 'TDS$%' --and dt.table_name not like 'HCF_%'
    group by di.owner, di.index_name, di.uniqueness, 
        dt.owner, dt.table_name, dt.last_analyzed, dt.monitoring
)

select
    -- common --
    ilts.index_owner, 
    ilts.index_name, 
    ilts.table_name, 
    ilts.uniqueness, 
    uc.constraint_type, 
    ilts.index_total_mb,
    -- monitoring --
    ilts.monitoring tbl_monitoring, 
    ou.monitoring idx_monitoring, 
    ou.used index_used, 
    to_date(ou.start_monitoring, 'mm/dd/yyyy hh24:mi:ss') start_index_monitoring,
    iu.last_used last_index_used, 
    -- dml stats -- 
    ilts.last_analyzed, 
    dm.timestamp last_data_modification, 
    dm.inserts, 
    dm.updates, 
    dm.deletes, 
    round((dm.inserts + dm.updates + dm.deletes) / ((dm.timestamp - ilts.last_analyzed) * 1440)) row_modified_per_minute
from index_list_tab_space ilts
    left join dba_index_usage iu on iu.owner = ilts.index_owner and iu.name = ilts.index_name
    left join user_object_usage ou on ou.index_name = ilts.index_name and ou.table_name = ilts.table_name
    left join dba_tab_modifications dm on dm.table_owner = ilts.table_owner and dm.table_name = ilts.table_name and dm.partition_name is null
    left join user_constraints uc on uc.index_owner = ilts.index_owner and uc.index_name = ilts.index_name
--where (ou.used is null and ou.monitoring = 'YES')
--    or (iu.last_used is null and exists (select 0 from v$index_usage_info where index_stats_enabled = 1))
--    or (greatest(ou.used, iu.last_used) <= sysdate - (select depth from source))
order by index_total_mb desc nulls last;



with source as (
    select '25ba6pqzmb88d' sql_id, 819029706 plan_hash_value, 17733050 sql_exec_id from dual
)
select 
    decode(t.column_value, 0, null, spm.plan_line_id) id, --sp.parent_id, nullif(sp.depth - 1, -1) depth, 
    -- sql_id, cn = sql child number, hv = plan hash value, ela = elapsed time per seconds, disk = physical read, lio = consistent gets (cr + cu), r = rows processed
    case when t.column_value = 0 and rownum = 1 then --null
            'SQL_ID = ' || spm.sql_id || 
            ', phv = '  || spm.sql_plan_hash_value ||
            ', eid = '  || spm.sql_exec_id 
          when t.column_value = 0 then  
            (select 
                'SQLSTAT: ' ||
                ', e = '    || s.delta_execution_count || 
                ', ela = '  || to_char(round(s.delta_elapsed_time / 1e6, 2), 'fm999G990D00', 'nls_numeric_characters=''. ''') || 
                ', cpu = '  || to_char(round(s.delta_cpu_time / 1e6, 2), 'fm999G990D00', 'nls_numeric_characters=''. ''') || 
                ', io = '   || to_char(round(s.delta_user_io_wait_time / 1e6, 2), 'fm999G990D00', 'nls_numeric_characters=''. ''') ||
                ', cc = '   || to_char(round(s.delta_concurrency_time / 1e6, 2), 'fm999G990D00', 'nls_numeric_characters=''. ''') ||
                ', parse = '|| to_char(round(s.avg_hard_parse_time / 1e6, 2), 'fm999G990D00', 'nls_numeric_characters=''. ''') ||
                ', disk = ' || s.delta_disk_reads ||
                ', lio = '  || s.delta_buffer_gets || 
                ', r = '    || s.delta_rows_processed ||
                ', px = '   || s.delta_px_servers_executions
            from v$sqlstats s where s.sql_id = src.sql_id and s.plan_hash_value = src.plan_hash_value)
          else
        --
        lpad(' ', 4 * spm.plan_depth) || spm.plan_operation || --nvl2(spm.plan_optimizer, '  Optimizer=' || spm.plan_optimizer, null) ||
        nvl2(spm.plan_options, ' (' || spm.plan_options || ')', null) || 
        nvl2(spm.plan_object_name, ' OF ''' || nvl2(spm.plan_object_owner, spm.plan_object_owner || '.', null) || spm.plan_object_name || '''', null) ||
        decode(spm.plan_object_type, 'INDEX (UNIQUE)', ' (UNIQUE)') ||
        '  (Cost=' || spm.plan_cost || ' Card=' || spm.plan_cardinality || ' Bytes=' || spm.plan_bytes || ')'
        end sqlplan, 
    spm.starts,
    spm.output_rows a_rows,
    numtodsinterval(spm.last_refresh_time - spm.first_refresh_time, 'day') a_time,
    spm.physical_read_requests + spm.physical_write_requests rwreq,
    spm.physical_read_bytes + spm.physical_write_bytes rwbyt,
    spm.workarea_max_mem max_mem,
    spm.workarea_max_tempseg max_temp
--    ,sp.access_predicates
--    ,sp.filter_predicates
--	,sp.projection
from source src
    left join v$sql_plan_monitor spm on spm.sql_id = src.sql_id and spm.sql_plan_hash_value = src.plan_hash_value and spm.sql_exec_id = src.sql_exec_id
    left join table(sys.odcinumberlist(0,0,1)) t on t.column_value >= spm.plan_line_id
--where s.sql_id = '4m7aatg5uw8sh'
order by spm.sql_plan_hash_value, spm.plan_line_id, t.column_value;
