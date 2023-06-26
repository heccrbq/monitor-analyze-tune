select df.tablespace_name "Tablespace",
totalusedspace "Used MB",
(df.totalspace - tu.totalusedspace) "Free MB",
df.totalspace "Total MB",
round(100 * ( (df.totalspace - tu.totalusedspace)/ df.totalspace))
"Pct. Free"
from
(select tablespace_name,
round(sum(bytes) / 1048576) TotalSpace
from dba_data_files
group by tablespace_name) df,
(select round(sum(bytes)/(1024*1024)) totalusedspace, tablespace_name
from dba_segments
group by tablespace_name) tu
where df.tablespace_name = tu.tablespace_name;

-- Стоить помнить, что dba_free_space учитывает в качестве свободного места объекты, которые находятся в корзине
select b.tablespace_name, tbs_size SizeMb, a.free_space FreeMb
from  (select tablespace_name, round(sum(bytes)/1024/1024 ,2) as free_space
       from dba_free_space
       group by tablespace_name) a,
      (select tablespace_name, sum(bytes)/1024/1024 as tbs_size
       from dba_data_files
       group by tablespace_name
       union 
       select tablespace_name, sum(bytes)/1024/1024 tbs_size
from dba_temp_files
group by tablespace_name ) b
where a.tablespace_name(+)=b.tablespace_name;
