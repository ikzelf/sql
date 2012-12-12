select  ss.begin_interval_time                  bint
,       extract (day from (ss.begin_interval_time - sysdate))*24
      + extract (hour from (ss.begin_interval_time - sysdate))      x
,       s.sql_id
,       s.plan_hash_value                       phv
,       s.sql_profile                           prof
,       s.executions_delta                      execs
,       s.optimizer_cost                        cost
,       s.fetches_delta                         fetchs
,       s.sorts_delta                           sorts
,       s.px_servers_execs_delta                pxps
,       s.disk_reads_delta                      phrds
,       s.buffer_gets_delta                     lios
,       s.rows_processed_delta                  rowz
,       s.elapsed_time_delta                    ela_ms
from DBA_HIST_SQLSTAT s
,    DBA_HIST_SNAPSHOT ss
where ss.snap_id         = S.snap_id
  and ss.instance_number = S.instance_number
  and s.executions_delta > 0
  and s.sql_id = '${sql_id}'
order by ss.begin_interval_time, s.sql_id