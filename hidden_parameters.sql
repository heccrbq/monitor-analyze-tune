select 
    a.ksppinm parameter,
    a.ksppdesc description,
    b.ksppstvl session_value,
    c.ksppstvl instance_value
from x$ksppi a,
    x$ksppcv b,
    x$ksppsv c
where a.indx = b.indx
    and a.indx = c.indx
    and a.ksppinm = '_optimizer_gather_stats_on_load'
--    and a.ksppinm like '/_%optimizer%stats%' escape '/'
order by a.ksppinm;
