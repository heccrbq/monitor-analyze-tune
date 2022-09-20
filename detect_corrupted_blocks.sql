/**
 * =============================================================================================
 * Скрипт для поиска битых блоков
 * =============================================================================================
 * @param   l_object_owner (VARCHAR2)   Схема/владелец объекта
 * @param   l_object_name  (VARCHAR2)   Наименование объекта
 * =============================================================================================
 * Описание полей:
 *  - v$session.action  : в этом поле будет указан прогресс сессии
 *  - v$session_longops : в этом представлении будет прогресс команды analyze
 * =============================================================================================
 */
whenever sqlerror exit rollback
set serveroutput on size unlimited
set timing on
declare
    l_object_owner all_objects.owner%type := 'STAGE';
    l_object_name  all_objects.object_name%type := 'REGULATED_REPORT_D';
    --
    l_nmbr pls_integer := 0;
    detected_corrupted_block exception;
    pragma exception_init(detected_currupted_block, -1578);
begin
    for i in (
        select 
            object_type, owner, object_name, count(1)over() cnt
        from dba_objects 
        where object_type in ('TABLE', 'INDEX') 
            and owner = l_object_owner
            and (object_name = l_object_name
                or l_object_name is null))
    loop
        l_nmbr := l_nmbr + 1;
        dbms_application_info.set_action('ELEMENT #' || l_nmbr || ' of ' || i.cnt || ': ' || 
            i.owner || '.' || i.object_name || ' (' || i.object_type || ')');
        begin
            execute immediate 'analyze ' || i.object_type || ' ' || 
                                            i.owner || '.' || 
                                            i.object_name || ' validate structure';
            exception
                when detected_corrupted_block then
                    dbms_output.put_line(i.owner || '.' || 
                                         i.object_name || 
                                         ' (' || i.object_type || ') ' ||
                                         sqlerrm);
                                         
        end;
        
        dbms_output.put_line(i.object_type || ' ' || 
                             i.owner || '.' || 
                             i.object_name ||
                             ' successfully validated');
    end loop;
end;
/


-- ACTION monitoring
select s.action, s.* from v$session s where osuser = sys_context('userenv','os_user');


-- Search corrupted blocks after RMAN
select * from dba_extents 
where (file_id,block_id) in (
     select file#, block# from v$database_block_corruption);
