
  CREATE OR REPLACE FUNCTION public.sea_calculate_leave_hours(OUT return_status character varying)
  RETURNS character varying AS
$BODY$
   BEGIN



  	DECLARE
        rec_date_list            	record;
		rec_leaves 					record;
		l_diff_hours1 				time;
		l_diff_hours2 				time;
		l_worked_hours 				numeric;
		l_checkin 					timestamp;
		l_check_out 				timestamp;
		l_number_days 				numeric;
		cnt 						integer;
	BEGIN
		cnt=0;

    	FOR rec_leaves IN 	select hh.id,hh.private_name,(hh.date_from+ '05:30:00'::interval) date_from,(hh.date_to+ '05:30:00'::interval) date_to,hh.employee_id,hh.number_of_days,'LEAVE' holiday_status
						 	from hr_leave hh,hr_leave_type hhs
						 	WHERE  	hh.holiday_status_id=hhs.id
						 	AND 	hh.state not in ('refuse')
						 	AND 	extract('year' from hh.date_from)::int=EXTRACT('year' from current_date)::int
						 	--AND 	employee_id=886

		LOOP

			RAISE NOTICE 'number_of_days : %',ABS(rec_leaves.number_of_days);
			FOR rec_date_list IN
					WITH dates_list as (
					select ROW_NUMBER() over(order by date1) rn , date1::date
					from generate_series(rec_leaves.date_from::date,rec_leaves.date_to::date,interval '1 day' ) as t(date1)
					where  date_part('dow'::text, date1::date) not in (0,6)
					and date1 not in (select check_in::date from hr_attendance where remarks='public holidays')
					) select date1 from dates_list where rn<=ceil(ABS(rec_leaves.number_of_days))
			LOOP
				/*IF date_part('dow'::text, rec_date_list.date1::date)=0 OR date_part('dow'::text, rec_date_list.date1::date) =6 THEN
					rec_date_list.date1=rec_date_list.date1::date+2;
					RAISE NOTICE 'date_list : %,emp_id : %',rec_date_list.date1,rec_leaves.employee_id;
					select sum(worked_hours),min(check_in),max(check_out) into l_worked_hours,l_checkin,l_check_out from hr_attendance where employee_id=rec_leaves.employee_id and check_in::date=rec_date_list.date1::date;
					IF coalesce(l_worked_hours,0)>0 AND coalesce(l_worked_hours,0)<8 AND ABS(rec_leaves.number_of_days)<1 THEN

						RAISE NOTICE 'worked_hours less';
						l_diff_hours1=case when (l_checkin + '05:30:00'::interval)::time>'10:00:00'::time then (l_checkin+ '05:30:00'::interval)::time - '10:00:00'::time end ;
						l_diff_hours2=case when (l_check_out+ '05:30:00'::interval)::time<'19:00:00'::time then '19:00:00'::time-(l_check_out+ '05:30:00'::interval)::time end;
						IF l_diff_hours1<l_diff_hours2 THEN
							RAISE NOTICE 'inserting eve time emp_id :%,check_in: %,check_out : % ',rec_leaves.employee_id,l_check_out::timestamp without time zone,(l_check_out +interval '1h' *4)::timestamp without time zone;
							insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
							values(rec_leaves.employee_id,l_check_out::timestamp without time zone,(l_check_out +interval '1h' *4)::timestamp without time zone,4,'LEAVES',rec_leaves.name);
						ELSIF l_diff_hours1>=l_diff_hours2 THEN
							RAISE NOTICE 'inserting eve time emp_id :%,check_in: %,check_out : % ',rec_leaves.employee_id,(l_checkin - interval '1h' *4)::timestamp without time zone,l_checkin::timestamp without time zone;
							insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
							values(rec_leaves.employee_id,(l_checkin - interval '1h' *4)::timestamp without time zone,l_checkin::timestamp without time zone,4,'LEAVES',rec_leaves.name);
						END IF;
					ELSIF ABS(rec_leaves.number_of_days)<1 THEN
						RAISE NOTICE 'Worked hours 4 : emp_id:%,check_in : %,check_out: %',rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,((rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone+ interval '1h' *4)::timestamp without time zone;
						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
							values(rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,((rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone+ interval '1h' *4)::timestamp without time zone,4,'LEAVES',rec_leaves.name);
					ELSIF ABS(rec_leaves.number_of_days)>=1 THEN
						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description)
							values(rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,(rec_date_list.date1||' '||'13:30:00'::time)::timestamp without time zone,8,'LEAVES',rec_leaves.name);
						RAISE NOTICE 'Worked hours 8 : emp_id:%,check_in : %,check_out: %, rec_leaves_name : %',rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,(rec_date_list.date1||' '||'13:30:00'::time)::timestamp without time zone,rec_leaves.name;
						RAISE NOTICE 'data inserted';
					END IF;
					cnt=cnt+1;
				ELSE*/

					RAISE NOTICE 'date_list : %,emp_id : %',rec_date_list.date1,rec_leaves.employee_id;
					select sum(worked_hours),min(check_in),max(check_out) into l_worked_hours,l_checkin,l_check_out from hr_attendance where employee_id=rec_leaves.employee_id and check_in::date=rec_date_list.date1::date;
					IF coalesce(l_worked_hours,0)>0 AND coalesce(l_worked_hours,0)<8 AND ABS(rec_leaves.number_of_days)<1 THEN

						RAISE NOTICE 'worked_hours less';
						l_diff_hours1=case when (l_checkin + '05:30:00'::interval)::time>'10:00:00'::time then (l_checkin+ '05:30:00'::interval)::time - '10:00:00'::time end ;
						l_diff_hours2=case when (l_check_out+ '05:30:00'::interval)::time<'19:00:00'::time then '19:00:00'::time-(l_check_out+ '05:30:00'::interval)::time end;
						IF l_diff_hours1<l_diff_hours2 THEN
							RAISE NOTICE 'inserting eve time emp_id :%,check_in: %,check_out : % ',rec_leaves.employee_id,l_check_out::timestamp without time zone,(l_check_out +interval '1h' *4)::timestamp without time zone;
							insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description,facility)
							values(rec_leaves.employee_id,l_check_out::timestamp without time zone,(l_check_out +interval '1h' *4)::timestamp without time zone,4,rec_leaves.holiday_status,rec_leaves.name,rec_leaves.holiday_status)  ON CONFLICT ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key DO NOTHING;
						ELSIF l_diff_hours1>=l_diff_hours2 THEN
							RAISE NOTICE 'inserting eve time emp_id :%,check_in: %,check_out : % ',rec_leaves.employee_id,(l_checkin - interval '1h' *4)::timestamp without time zone,l_checkin::timestamp without time zone;
							insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description,facility)
							values(rec_leaves.employee_id,(l_checkin - interval '1h' *4)::timestamp without time zone,l_checkin::timestamp without time zone,4,rec_leaves.holiday_status,rec_leaves.name,rec_leaves.holiday_status)  ON CONFLICT ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key DO NOTHING;
						END IF;
					ELSIF ABS(rec_leaves.number_of_days)<1 THEN
						RAISE NOTICE 'Worked hours 4 : emp_id:%,check_in : %,check_out: %',rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,((rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone+ interval '1h' *4)::timestamp without time zone;

						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description,facility)
							values(rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,((rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone+ interval '1h' *4)::timestamp without time zone,4,rec_leaves.holiday_status,rec_leaves.name,rec_leaves.holiday_status)  ON CONFLICT ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key DO NOTHING;
					ELSIF ABS(rec_leaves.number_of_days)>=1 THEN
						insert into hr_attendance ( employee_id, check_in, check_out, worked_hours,remarks, description,facility)
							values(rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,(rec_date_list.date1||' '||'13:30:00'::time)::timestamp without time zone,8,rec_leaves.holiday_status,rec_leaves.name,rec_leaves.holiday_status) ON CONFLICT ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key DO NOTHING;
						RAISE NOTICE 'Worked hours 8 : emp_id:%,check_in : %,check_out: %, rec_leaves_name : %,facility : %',rec_leaves.employee_id,(rec_date_list.date1||' '||'04:30:00'::time)::timestamp without time zone,(rec_date_list.date1||' '||'13:30:00'::time)::timestamp without time zone,rec_leaves.name,rec_leaves.holiday_status;
						RAISE NOTICE 'data inserted';
					END IF;
				--END IF;
-- 			            rec_leaves.number_of_days=ABS(rec_leaves.number_of_days)-1;

			END LOOP;



		END LOOP;


	return_status:='Success';
		EXCEPTION
		WHEN OTHERS THEN
		RAISE NOTICE 'SQLError %:%',SQLSTATE,SQLERRM;
		return_status:='SQLError '||SQLSTATE||':'||SQLERRM;


    END;




  END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
