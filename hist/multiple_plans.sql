/**
 * =============================================================================================
 * Поиск запросов с несколькихи планами выполнения с вычислением разницы времени работы планов 
 * =============================================================================================
 * @param   btime  (DATE)   Начало периода
 * @param   etime  (DATE)   Окончание периода
 * =============================================================================================
 * Описание полей:
 *  - sql_id         : уникальный идентификатор запроса (SQL id)
 *  - loaded_plans   : количество найденны планов выполнения для запроса
 *  - last_load_time : время последнего снепшота, где был найден запрос
 *  - min_elapsed    : минимальное время выполнения запроса по одному из планов
 *  - max_elapsed    : максимальное время выполнения запроса по одному из планов
 *  - percent        : процентное соотношение времени выполнения запроса лучшего и худшего 
                     : плана выполнения
 * =============================================================================================
 */
with source as (
    select trunc(sysdate) - 30 btime, sysdate etime from dual
),
stat as (
    select
        *
    from source s
        join dba_hist_snapshot w on w.begin_interval_time between s.btime and s.etime
        join dba_hist_sqlstat st on st.snap_id = w.snap_id
                                and st.dbid = w.dbid
                                and st.instance_number = w.instance_number
    where st.plan_hash_value <> 0
)
select 
    st.sql_id, 
    count(distinct st.plan_hash_value) loaded_plans, 
    cast(max(st.begin_interval_time) as date) last_load_time,
    min(st1.ela) min_elapsed,
    max(st1.ela) max_elapsed,
    round(decode(min(st1.ela), 0, 0, abs(1 - max(st1.ela) / min(st1.ela))) * 100) percent
from stat st
    left join (
        select
            sql_id, plan_hash_value, round(sum(elapsed_time_delta) / greatest(sum(executions_delta), 1) / 1e6, 4) AS ela
        from stat
        group by sql_id,
            plan_hash_value
    ) st1 on st1.sql_id = st.sql_id
group by st.sql_id
having count(distinct st.plan_hash_value) > 1
order by percent desc;
