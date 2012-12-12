select sql_id
      , phv
      , min(bint) first_exe, max(bint) last_exe
      ,round(regr_r2 (ela_ms, x),2) rsqr
      ,round(regr_slope (ela_ms, x),2) slope
      ,regr_count (ela_ms,x) points
      ,round(regr_intercept (ela_ms,x),2) b
      ,round(avg(ela_ms)) avg_ela
      ,count(prof)        profs
from (
select  ss.begin_interval_time                  bint
,       extract (day from (ss.begin_interval_time - sysdate))*24
      + extract (hour from (ss.begin_interval_time - sysdate))      x
,       s.sql_id
,       s.plan_hash_value                       phv
,       s.executions_delta                      execs
,       s.optimizer_cost                        cost
,       s.fetches_delta                         fetchs
,       s.sorts_delta                           sorts
,       s.px_servers_execs_delta                pxps
,       s.disk_reads_delta                      phrds
,       s.buffer_gets_delta                     lios
,       s.rows_processed_delta                  rowz
,       s.elapsed_time_delta                    ela_ms
,       s.sql_profile                           prof
from DBA_HIST_SQLSTAT s
,    DBA_HIST_SNAPSHOT ss
where ss.snap_id         = S.snap_id
  and ss.instance_number = S.instance_number
  and s.executions_delta > 0
order by ss.begin_interval_time, s.sql_id
)
group by sql_id, phv
having regr_count (ela_ms,x) > 10
order by slope desc -- most slowing first