select 
    status, sid, sql_exec_id, sql_exec_start, sql_id, sql_plan_hash_value, 
    output_rows, numtodsinterval((last_refresh_time - sql_exec_start),'day') ela,
    (select sql_fulltext from v$sqlarea sa where sa.sql_id = sm.sql_id and sa.plan_hash_value = sm.sql_plan_hash_value) sqltext
from v$sql_plan_monitor sm
where sql_id in ('a7rrnrpm3sk9u') and plan_line_id = 0
order by sql_id, sql_exec_start desc;

select * from table(dbms_xplan.display_cursor ('a7rrnrpm3sk9u'));

select * from v$sql_plan_monitor where sql_id = 'a7rrnrpm3sk9u' and sql_exec_id = 16777298;


select 
    decode(t.column_value, 0, null, sp.id) id, --sp.parent_id, nullif(sp.depth - 1, -1) depth, 
    decode(t.column_value, 0, 
        -- sql_id, cn = sql child number, hv = plan hash value, ela = elapsed time per seconds, disk = physical read, lio = consistent gets (cr + cu), r = rows processed
		'SQL_ID = ' || s.sql_id || ', hv = ' || s.plan_hash_value || --', cn = ' || s.child_number || 
        ', ela = ' || replace(round(s.elapsed_time / 1e6, 2), ',', '.') || 
		', cpu = ' || replace(round(s.cpu_time / 1e6, 2), ',', '.') ||
		', io = ' || replace(round(s.user_io_wait_time / 1e6, 2), ',', '.') ||
        ', disk = ' || s.disk_reads || ', lio = ' || s.buffer_gets || ', r = ' || s.rows_processed,
        --
        lpad(' ', 4*depth) || sp.operation || nvl2(sp.optimizer, '  Optimizer=' || sp.optimizer, null) ||
        nvl2(sp.options, ' (' || sp.options || ')', null) || 
        nvl2(sp.object_name, ' OF ''' || nvl2(sp.object_owner, sp.object_owner || '.', null) || sp.object_name || '''', null) ||
        decode(sp.object_type, 'INDEX (UNIQUE)', ' (UNIQUE)') ||
        '  (Cost=' || cost || ' Card=' || sp.cardinality || ' Bytes=' || bytes || ')') sqlplan,
    spm.starts,
    spm.output_rows,
    spm.physical_read_requests + spm.physical_write_requests rwreq,
    spm.physical_read_bytes + spm.physical_write_bytes rwbyt,
    spm.workarea_max_mem max_mem,
    spm.workarea_max_tempseg max_temp
    ,sp.access_predicates
    ,sp.filter_predicates
	,sp.projection
from v$sqlarea s
    join v$sql_plan sp on sp.sql_id = s.sql_id and sp.plan_hash_value = s.plan_hash_value
--    left join v$sql_plan_statistics sps on sps.address = sp.address and sps.child_address = sp.child_address and sp.id = sps.operation_id
    left join v$sql_plan_monitor spm on spm.sql_id = sp.sql_id and spm.sql_plan_hash_value = sp.plan_hash_value and spm.plan_line_id = sp.id and spm.sql_exec_id = 16777300
    left join table(sys.odcinumberlist(0,1)) t on t.column_value >= sp.id
where s.sql_id = 'a7rrnrpm3sk9u'
order by s.plan_hash_value, sp.id, t.column_value;
