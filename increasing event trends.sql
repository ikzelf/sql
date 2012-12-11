select m.*, ${days} days from (
SELECT
    event_name,
    ROUND(regr_r2 (delta_milli, snap_id),2)       rsqr ,
    ROUND(regr_slope (delta_milli, snap_id),2)    slope ,
    regr_count (delta_milli,snap_id)              points ,
    ROUND(regr_intercept (delta_milli,snap_id),2) b,
    avg(delta_milli),
    stddev(delta_milli)
FROM
    (
        SELECT
            snap_id,
            event_name,
            sum_milli - prev_milli delta_milli,
            avg(sum_milli - prev_milli)  over (partition by   event_name) avg_delta_milli,
            stddev(sum_milli - prev_milli) over (partition by event_name) sdev_milli
        FROM
            (
                SELECT
                    snap_id,
                    sum_milli,
                    lag(sum_milli) over (partition BY event_name, startup_time ORDER BY end_interval_time ) prev_milli,
                    event_name,
                    startup_time
                FROM
                    (
                        SELECT DISTINCT
                            snp.snap_id,
                            snp.end_interval_time,
                            SUM(sst.wait_time_milli * sst.wait_count) over (partition BY
                            snp.snap_id, sst.event_name, snp.startup_time) sum_milli,
                            sst.event_name,
                            snp.startup_time,
                            to_char(snp.end_interval_time, 'dy') shortday
                        FROM
                            dba_hist_snapshot snp,
                            dba_hist_event_histogram sst
                        WHERE
                            snp.end_interval_time BETWEEN SYSDATE - ${days} AND SYSDATE
                        and instr('${dy_list}', to_char(snp.end_interval_time,'dy')) > 0      -- dy_list: mon,tue,wed ...
                        and instr('${hh24_list}', to_char(snp.end_interval_time,'hh24')) > 0  -- hh24_list: 09,10,14,15 ...
                        AND sst.dbid = snp.dbid
                        AND sst.instance_number = snp.instance_number
                        AND sst.snap_id = snp.snap_id
                       -- AND sst.event_name LIKE 'Backup: MML commit backup piece'
                        ) )
        WHERE
            NOT prev_milli IS NULL
             )
where delta_milli >= (avg_delta_milli - (sdev_milli*${n_deviation}))
  --  getting rid of extreme values (outside the range of avg +/- (N * standard deviation))
  and delta_milli <= (avg_delta_milli + (sdev_milli*${n_deviation}))
GROUP BY
    event_name
) m
where rsqr <> 0
and   slope <> 0
ORDER by slope desc, event_name