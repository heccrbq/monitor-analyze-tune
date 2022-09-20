-- generate estimated plan
explain plan for 
    select * From dual;
    
select * from table(dbms_xplan.display);


-- execution plan from memory
select * from table(dbms_xplan.display_cursor(sql_id          => 'akghvw4jy01bk', 
                                              cursor_child_no => 0, 
                                              format          => '+note'));


-- execution plan from SNAPSHOT
select * from table(dbms_xplan.display_awr(sql_id          => '1vfqf2sv20sns', 
                                           plan_hash_value => 2185578839,
--                                           db_id           => null,
                                           format          => '+note'));


-- basic view
select 
    plan_hash_value,
    id,
--    parent_id,
    lpad(' ', depth) || operation operation,
    options,
    object_owner,
    object_name,
    object_type,
    optimizer,
    cost,
    cardinality,
    bytes,
    cpu_cost,
    io_cost,
    access_predicates,
    filter_predicates
--from dba_hist_sql_plan p
from v$sql_plan p
where sql_id = 'akghvw4jy01bk'    
--    and child_number = 0
order by plan_hash_value, id;


-- SQL PLAN like TOAD
select 
    decode(t.column_value, 0, null, sp.id) id, 
--    sp.parent_id, nullif(sp.depth - 1, -1) depth, 
    decode(t.column_value, 0, 
        -- sql_id, cn = sql child number, hv = plan hash value, ela = elapsed time per seconds, disk = physical read, lio = consistent gets (cr + cu), r = rows processed
		'SQL_ID = ' || s.sql_id || ', hv = ' || s.plan_hash_value || ', cn = ' || s.child_number || 
        ', e = ' || s.executions ||
        ', ela = ' || replace(round(s.elapsed_time / 1e6, 2), ',', '.') || 
		', cpu = ' || replace(round(s.cpu_time / 1e6, 2), ',', '.') ||
		', io = ' || replace(round(s.user_io_wait_time / 1e6, 2), ',', '.') ||
        ', disk = ' || s.disk_reads || ', lio = ' || s.buffer_gets || ', r = ' || s.rows_processed,
        --
        lpad(' ', 4*depth) || sp.operation || nvl2(sp.optimizer, '  Optimizer=' || sp.optimizer, null) ||
        nvl2(sp.options, ' (' || sp.options || ')', null) || 
        nvl2(sp.object_name, ' OF ''' || nvl2(sp.object_owner, sp.object_owner || '.', null) || sp.object_name || '''', null) ||
        decode(sp.object_type, 'INDEX (UNIQUE)', ' (UNIQUE)') ||
        '  (Cost=' || cost || ' Card=' || sp.cardinality || ' Bytes=' || bytes || ')') sqlplan
    ,sp.access_predicates
    ,sp.filter_predicates
--	,sp.projection
from v$sql s
    join v$sql_plan sp on sp.address = s.address and sp.child_address = s.child_address
    left join table(sys.odcinumberlist(0,1)) t on t.column_value >= sp.id
where s.sql_id = 'akghvw4jy01bk'
    and s.child_number = 0
order by s.plan_hash_value, s.child_number, sp.id, t.column_value;
