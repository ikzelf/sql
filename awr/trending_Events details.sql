select to_char(sn.end_interval_time,'yyyymmdd hh24:mi:ss') end_time, m.event_name, m.delta_milli , ${days} days
,((m.snap_id * m.slope) + m.b) reg_calc, avg_delta_milli, sdev_milli
,to_char(sn.end_interval_time,'dy') dy, slope
from (
SELECT
    snap_id,
    event_name,
    sum_milli - prev_milli                                                          delta_milli,
    AVG(sum_milli - prev_milli)                     over (partition BY event_name)  avg_delta_milli,
    stddev(sum_milli - prev_milli)                  over (partition BY event_name)  sdev_milli,
    regr_slope (sum_milli - prev_milli, snap_id)    over (partition BY event_name)  slope,
    regr_intercept (sum_milli - prev_milli,snap_id) over (partition BY event_name)  b
FROM
    (
        SELECT
            snap_id,
            lag(snap_id)over (partition BY event_name, startup_time ORDER BY snap_id, event_name )
            prev_snap_id,
            sum_milli,
            lag(sum_milli) over (partition BY event_name, startup_time ORDER BY snap_id, event_name
            ) prev_milli,
            event_name,
            startup_time
        FROM
            (
                SELECT DISTINCT
                    snp.snap_id,
                    snp.end_interval_time,
                    SUM(sst.wait_time_milli * sst.wait_count) over (partition BY snp.snap_id,
                    sst.event_name, snp.startup_time) sum_milli,
                    sst.event_name,
                    snp.startup_time
                FROM
                    dba_hist_snapshot snp,
                    dba_hist_event_histogram sst
                WHERE
                    snp.end_interval_time BETWEEN SYSDATE - ${days} AND SYSDATE
                and instr('${dy_list}', to_char(snp.end_interval_time,'dy')) > 0
                and instr('${hh24_list}', to_char(snp.end_interval_time,'hh24')) > 0
                AND sst.dbid = snp.dbid
                AND sst.instance_number = snp.instance_number
                AND sst.snap_id = snp.snap_id
                AND sst.event_name = '${event_name}' ) )
WHERE
    NOT prev_milli IS NULL
) m
, dba_hist_snapshot sn
where m.snap_id = sn.snap_id
and m.delta_milli >= (avg_delta_milli - (sdev_milli*${n_deviation}))
and m.delta_milli <= (avg_delta_milli + (sdev_milli*${n_deviation}))
order by m.snap_id