select 
    block_class, status, dirty, temp, ping, stale, direct, new , count(1) blkcount, sum(count(1))over() blkcount_total
from (
    select decode(bh.class#,1, 'data block',            2, 'sort block',          3, 'save undo block',
                            4, 'segment header',        5, 'save undo header',    6, 'free list',
                            7, 'extent map',            8, '1st level bmb',       9, '2nd level bmb',
                           10, '3rd level bmb',        11, 'bitmap block',       12, 'bitmap index block',
                           13, 'file header block',    14, 'unused',             15, 'system undo header',
                           16, 'system undo block',    17, 'undo header',        18, 'undo block') block_class, 
    bh.status, bh.dirty, bh.temp, bh.ping, bh.stale, bh.direct, bh.new        
from v$bh bh,
    dba_objects o
where o.data_object_id  = bh.objd
    and o.object_name = 'TACCOUNT') 
group by block_class, status, dirty, temp, ping, stale, direct, new;
