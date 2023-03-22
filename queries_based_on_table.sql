with source as (
    select 'UBRR_FSSP_CODE_INCOME_CALC_TWR' table_name from dual
),
queries as (
    select /*+no_merge*/ sql_id, sql_text from dba_hist_sqltext hst, source s where upper(sql_text) like '%' || s.table_name || '%'
)
,
stat as (
    select q.sql_id sqlid, s.plan_hash_value phv, 
        to_char(substr(q.sql_text, 1, 4000)) sql_text,
        trunc(w.begin_interval_time) tl,
        s.executions_delta        e,
        s.elapsed_time_delta      ela,
        s.cpu_time_delta          cpu,
        s.iowait_delta            io,
        s.ccwait_delta            cc,
        s.apwait_delta            app,
        s.plsexec_time_delta      plsql,
        s.javexec_time_delta      java,
        s.disk_reads_delta        disk,
        s.buffer_gets_delta       lio,
        s.rows_processed_delta    r,
        s.parse_calls_delta       pc,
        s.px_servers_execs_delta  px,
        dense_rank()over(partition by s.sql_id order by trunc(w.begin_interval_time) desc) drnk
    from queries q 
        left join dba_hist_sqlstat s on s.sql_id = q.sql_id
        left join dba_hist_snapshot w on w.snap_id = s.snap_id
)
select 
    s.sqlid, 
--    s.phv,
    s.tl,
    sum(s.e)                                             AS e,
    round(sum(s.ela)   / greatest(sum(s.e), 1) / 1e3, 4) AS ela,
    round(sum(s.cpu)   / greatest(sum(s.e), 1) / 1e3, 4) AS cpu,
    round(sum(s.io)    / greatest(sum(s.e), 1) / 1e3, 4) AS io,
    round(sum(s.cc)    / greatest(sum(s.e), 1) / 1e3, 4) AS cc,
    round(sum(s.app)   / greatest(sum(s.e), 1) / 1e3, 4) AS app,
    round(sum(s.plsql) / greatest(sum(s.e), 1) / 1e3, 4) AS plsql,
    round(sum(s.java)  / greatest(sum(s.e), 1) / 1e3, 4) AS java,
    round(sum(s.disk)  / greatest(sum(s.e), 1)) AS disk,
    round(sum(s.lio)   / greatest(sum(s.e), 1)) AS lio,
    round(sum(s.r)     / greatest(sum(s.e), 1)) AS r,
    round(sum(s.pc)    / greatest(sum(s.e), 1)) AS pc,
    round(sum(s.px)    / greatest(sum(s.e), 1)) AS px
    ,s.sql_text
from stat s
where s.drnk = 1
--    and s.sqlid = '11f175mbhbvsp'
group by s.sqlid, 
--    s.phv,
    s.sql_text,
    s.tl
order by ela * greatest(e, 1) desc nulls last;
