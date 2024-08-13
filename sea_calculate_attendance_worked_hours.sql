
  CREATE OR REPLACE FUNCTION public.sea_calculate_attendance_worked_hours(p_from_date character varying,p_to_date character varying, OUT return_status character varying)
  RETURNS character varying AS
$BODY$
   BEGIN




    DECLARE
        rec_hr_att_data            	record;
		rec_distinct_date 			record;
		l_cur_dir_val 					character varying:=NULL;
		l_prev_dir_val 				character varying:=NULL;
		cnt 								integer:=1;
		l_cur_logtime_val 			character varying:=NULL;
		l_worked_hours 				numeric;
		l_status 					character varying:=NULL;

		l_cur_distinct_date CURSOR IS
		select 	employee_id
					,check_in::date
		from 	hr_attendance
		where
					worked_hours IS NULL
		--AND     check_out IS NOT NULL
		--AND 	employee_id=1649
		--AND 	check_in::date='2019-01-10'
		group by employee_id,check_in::date
		order by employee_id,check_in::date;


        l_cur_emp_data CURSOR(l_emp_id INTEGER,l_date character varying)
		FOR
        select *from (
			select  employee_id
							,check_in   log_time
							,'IN' dir
					from    hr_attendance
					where   worked_hours IS NULL
					--AND     check_out IS NOT NULL
					AND 	employee_id=l_emp_id
					AND 	check_in::date=l_date::date
			UNION ALL
			select  employee_id
							,check_out log_time
							,'OUT' dir
					from    hr_attendance
					where   worked_hours IS NULL
					--AND     check_out IS NOT NULL
					AND 	employee_id=l_emp_id
					AND 	check_out::date=l_date::date

		) a order by log_time;


    BEGIN

    	/*delete from hr_attendance where remarks='LEAVES' and description IS NOT NULL;
    	FOR rec_leaves IN 	select id,name,date_from,date_to,employee_id,number_of_days
						 	from hr_leave;
		LOOP
			FOR rec_date_list IN
					select date1::date
					from generate_series(date_from::date,date_from::date+ceil(number_of_days)::int) as t(date1);
			LOOP
				select sum(worked_hours),min(check_in),max(check_out) into l_worked_hours,l_checkin,l_check_out from hr_attendance where employee_id=rec_leaves.employee_id and check_in::date=rec_date_list.date1::date;
				IF l_worked_hours>0 AND l_worked_hours<8 THEN
					l_diff_hours1=case when (l_checkin + '05:30:00'::interval)::time>'10:00:00'::time then (l_checkin+ '05:30:00'::interval)::time - '10:00:00'::time end ;
					l_diff_hours2=case when (l_check_out+ '05:30:00'::interval)::time<'19:00:00'::time then '19:00:00'::time-(l_check_out+ '05:30:00'::interval)::time;
					IF l_diff_hours1<l_diff_hours2 THEN
						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
						values(rec_leaves.employee_id,l_check_out::timestamp without time zone,(l_check_out +interval '1h' *4)::timestamp without time zone,4,'LEAVES',rec_leaves.name);
					ELSIF l_diff_hours1>=l_diff_hours2 THEN
						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
						values(rec_leaves.employee_id,(l_checkin - interval '1h' *4),l_checkin::timestamp without time zone,4,'LEAVES',rec_leaves.name);
					END IF;
				ELSE
					insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
						values(rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,(rec_date_list.date1||' '||'13:30:00'::time)::timestamp without time zone,8,'LEAVES',rec_leaves.name);
				END IF;

			END LOOP;

		END LOOP;

    	WITH date_list as (
			select employee_id,name description,'LEAVES' remarks
			,CASE WHEN (date_from + '05:30:00'::interval)::time<'10:00:00'::time then (date_from::date||' '||'04:30:00'::time)::timestamp without time zone   else date_from end,

			CASE WHEN (date_to + '05:30:00'::interval)::time>'19:00:00'::time then (date_to::date||' '||'13:30:00'::time)::timestamp without time zone else date_to end
			from hr_leave
			where (type='remove' AND state not in ('refuse'))
			--AND employee_id=878
			),dates_worked_hours as (
			select employee_id,description,remarks,date1,dl.date_to,case when date1::date<dl.date_to::date OR (dl.date_to::time-date1::time)>'08:00:00' then 8 else date_part('epoch'::text, (dl.date_to::time-date1::time)) / 28800::double precision end worked_hours from date_list dl,generate_series(dl.date_from,dl.date_to,interval '1 day') as t(date1)
			)insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
			select employee_id,case when dw.worked_hours=8 then (dw.date1::date||' '||'04:30:00'::time)::timestamp without time zone else date1::timestamp without time zone end start_date ,
			case when dw.worked_hours=8 then (dw.date1::date||' '||'13:30:00'::time)::timestamp without time zone else date_to::timestamp without time zone end end_date,
			ceil(case when dw.worked_hours<8 then dw.worked_hours*8 else dw.worked_hours end) worked_hours,
			remarks,
			description
			from dates_worked_hours dw
			where date_part('dow'::text, dw.date1::date) between 1 and 5
			on conflict ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key do nothing;

*/
		delete from hr_attendance where coalesce(char_length(trim(remarks)),0)>0;
		--delete from hr_attendance where remarks='public holidays';
		insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description,facility)
		select he.id emp_id,
		(hhpl.date||' 04:30:00')::timestamp without time zone l_check_in,
		(hhpl.date||' 12:30:00')::timestamp without time zone l_check_out,
		8 unit_amount,
		'public holidays' remarks,
		hhpl.name,
		'PUBLIC_HOLIDAY'
		from hr_employee he,
		resource_resource rr,
		hr_holidays_public_line hhpl,
		hr_holidays_public hhp,
		account_analytic_account aaa
		where he.active='t'
		AND he.resource_id=rr.id
		AND rr.active='t'
		AND hhp.id=hhpl.year_id
		AND hhp.year=EXTRACT('year' from current_date)::int
		AND aaa.name ILIKE '%sailotech%communications%'
		--AND pp.analytic_account_id=aaa.id
		--AND pp.id=pt.project_id
		--AND pt.name='Holiday'
		--AND pt.active='t'
		--AND hhpl.date > current_date
		--AND hhpl.date not in (select date from account_analytic_line where employee_id=he.id)
		--AND he.id=1550
		order by hhpl.date ;
		RAISE NOTICE 'public holidays data extracted and inserted into attendance';

		--delete from hr_attendance where remarks='LEAVES' ;
		select public.sea_calculate_leave_hours() into l_status;
    	RAISE NOTICE 'FUNCTION sea_calculate_leave_hours status : %',l_status;


		IF p_from_date='vineel' THEN
			p_from_date=NULL;
		END IF;
		IF p_to_date='hari' THEN
			p_to_date=NULL;
		END IF;

		IF p_from_date IS NULL AND p_to_date IS NULL
		THEN

			FOR rec_emp_id_date IN l_cur_distinct_date
			LOOP
				OPEN l_cur_emp_data(rec_emp_id_date.employee_id,rec_emp_id_date.check_in);
				LOOP
					FETCH l_cur_emp_data INTO rec_hr_att_data;

					EXIT WHEN NOT FOUND;

					RAISE NOTICE 'emp_id : %,dir : %, log_time : %',rec_hr_att_data.employee_id,rec_hr_att_data.dir,rec_hr_att_data.log_time;

					IF (l_cur_dir_val='IN' AND rec_hr_att_data.dir='IN') OR (l_cur_dir_val='OUT' AND rec_hr_att_data.dir='OUT')
					THEN
						UPDATE 	hr_attendance
						set 			remarks='Invalid entries'
						WHERE 	employee_id=rec_emp_id_date.employee_id
						AND 		date(check_in)=rec_emp_id_date.check_in;
						--EXIT;
					ELSIF (rec_hr_att_data.dir='OUT' AND l_cur_dir_val='IN') THEN
						RAISE NOTICE 'l_cur_dir_val : %,rec_hr_att_data_dir : %,rec_hr_att_data_log_time : %,l_cur_logtime_val : %', l_cur_dir_val,rec_hr_att_data.dir,rec_hr_att_data.log_time::timestamp,l_cur_logtime_val::timestamp;
						UPDATE 		hr_attendance
						set 				worked_hours=extract(epoch from (rec_hr_att_data.log_time::timestamp-l_cur_logtime_val::timestamp))/3600
						WHERE 		employee_id=rec_emp_id_date.employee_id
						AND 			check_in=l_cur_logtime_val::timestamp;

					END IF;
					l_cur_dir_val=rec_hr_att_data.dir;
					l_cur_logtime_val=rec_hr_att_data.log_time;

				END LOOP;
				CLOSE l_cur_emp_data;
				/*UPDATE hr_attendance set worked_hours=extract(epoch from (check_out::timestamp-check_in::timestamp))/3600
				where 	employee_id=rec_emp_id_date.employee_id
				AND date(check_in)=rec_emp_id_date.check_in;*/
				l_cur_dir_val=NULL;
			END LOOP;

		ELSIF p_from_date IS NOT NULL AND p_to_date IS NOT NULL
		THEN

			FOR rec_distinct_date IN
			select 	employee_id
						,check_in::date
			from 	hr_attendance
			where 	check_in::date between p_from_date::date AND p_to_date::date
			--AND 	employee_id=1528
			--AND 	check_in::date='2019-01-10'
			group by employee_id,check_in::date
			order by employee_id,check_in::date
			LOOP
				FOR  rec_hr_att_data IN
					select *from
					(
						select  employee_id
								,check_in   log_time
								,'IN' dir
						from    hr_attendance
						where  employee_id=rec_distinct_date.employee_id
						AND 	check_in::date=rec_distinct_date.check_in::date
					UNION ALL
						select  employee_id
								,check_out log_time
								,'OUT' dir
						from    hr_attendance
						where  employee_id=rec_distinct_date.employee_id
						AND 	check_out::date=rec_distinct_date.check_in::date

					) a order by log_time
				LOOP

					RAISE NOTICE 'emp_id : %,dir : %, log_time : %',rec_hr_att_data.employee_id,rec_hr_att_data.dir,rec_hr_att_data.log_time;

					IF (l_cur_dir_val='IN' AND rec_hr_att_data.dir='IN') OR (l_cur_dir_val='OUT' AND rec_hr_att_data.dir='OUT')
					THEN
						UPDATE 	hr_attendance
						set 			remarks='Invalid entries'
						WHERE 	employee_id=rec_distinct_date.employee_id
						AND 		date(check_in)=rec_distinct_date.check_in;

						UPDATE 		hr_attendance
						set 				worked_hours=NULL
						WHERE 		employee_id=rec_distinct_date.employee_id
						AND 			check_in=l_cur_logtime_val::timestamp;
						--EXIT;
					ELSIF (rec_hr_att_data.dir='OUT' AND l_cur_dir_val='IN') THEN

						l_worked_hours := extract(epoch from (rec_hr_att_data.log_time::timestamp-l_cur_logtime_val::timestamp))/3600;

						RAISE NOTICE 'l_cur_dir_val : %,rec_hr_att_data_dir : %,rec_hr_att_data_log_time : %,l_cur_logtime_val : %, l_worked_hours : %', l_cur_dir_val,rec_hr_att_data.dir,rec_hr_att_data.log_time::timestamp,l_cur_logtime_val::timestamp,l_worked_hours;
						UPDATE 		hr_attendance
						set 				worked_hours=extract(epoch from (rec_hr_att_data.log_time::timestamp-l_cur_logtime_val::timestamp))/3600
						WHERE 		employee_id=rec_distinct_date.employee_id
						AND 			check_in=l_cur_logtime_val::timestamp;

					END IF;
					l_cur_dir_val=rec_hr_att_data.dir;
					l_cur_logtime_val=rec_hr_att_data.log_time;

				END LOOP;

				/*UPDATE hr_attendance set worked_hours=extract(epoch from (check_out::timestamp-check_in::timestamp))/3600
				where 	employee_id=rec_emp_id_date.employee_id
				AND date(check_in)=rec_emp_id_date.check_in;*/
				l_cur_dir_val=NULL;
			END LOOP;

		END IF;
        return_status:='Worked hours calculated Successfully ';
		EXCEPTION
		WHEN OTHERS THEN
		RAISE NOTICE 'SQLError %:%',SQLSTATE,SQLERRM;
		return_status:='SQLError '||SQLSTATE||':'||SQLERRM;

    END;

  END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
