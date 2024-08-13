
  CREATE OR REPLACE FUNCTION public.sea_load_hr_attendance_msaccess_data(p_filepath character varying,p_facility_name character varying,OUT return_status character varying)
    RETURNS character varying AS
$BODY$
   BEGIN



    --variable_conflict use_variable
    DECLARE
        curtime timestamp := now();
        rec_stg_emp_data 			record;
        rec_att_base_data 			record;
        sql_stmt 					character varying;
		stg_fdw_cnt					integer;
		l_inseted_values 			character varying;
		l_error_message 			character varying;

        l_cur_emp_data CURSOR IS
        select 	person_id,
        		date(log_date_time) stg_date
        from 	stg_biometric_data
		where 	data_source='MSACCESS'
		--AND   person_id=302
        group by person_id,
 				 date(log_date_time)
 		order by person_id;

    BEGIN
    	EXECUTE 'CREATE EXTENSION IF NOT EXISTS file_fdw';
    	EXECUTE 'DROP SERVER IF EXISTS file_fdw_server CASCADE';
		EXECUTE 'CREATE SERVER file_fdw_server FOREIGN DATA WRAPPER file_fdw';
    	EXECUTE 'DROP FOREIGN TABLE IF EXISTS public.stg_msaccess_data_fdw';

    	select format('
				CREATE FOREIGN TABLE public.stg_msaccess_data_fdw
					(
					    file_datetime character varying,
						file_pid	character varying,
						file_FirstName	character varying,
						file_LastName	character varying,
						file_CardNumber	character varying,
						file_DeviceName	character varying,
						file_EventPoint	character varying,
						file_VerifyType	character varying,
						file_io_Status	character varying,
						file_EventDescription	character varying,
						file_Remarks character varying
					) SERVER file_fdw_server
					OPTIONS (format %s ,header %s, filename %s ,delimiter E'','', null '''')',quote_literal('csv'),quote_literal('true'),quote_literal(p_filepath))
				into
				sql_stmt;

				RAISE NOTICE 'sql_statement: %',sql_stmt;
				EXECUTE 	sql_stmt;
			BEGIN
				select count(1) into stg_fdw_cnt  from stg_msaccess_data_fdw;
				exception
    			WHEN OTHERS THEN
    				return_status:=SQLSTATE||' : '||SQLERRM;
    				RAISE EXCEPTION '%',return_status;
    				RAISE NOTICE '%',return_status;

			END;

		delete from stg_biometric_data where data_source='MSACCESS';
    	BEGIN
    		--START TRANSACTION;
    		INSERT INTO stg_biometric_data(log_date_time
    		                               ,person_id
										   ,emp_code
    		                               ,direction
    		                               ,data_source
    		                               ,facility
    		                               )
    		select 	file_datetime::timestamp,
    				file_pid::int,
					file_FirstName,
    				file_io_Status,
    				'MSACCESS' data_source,
    				p_facility_name
    		from  	stg_msaccess_data_fdw
    		where 	file_pid IS NOT NULL;
			--select *from stg_msaccess_data_fdw
			--commit;
    	exception
    	WHEN OTHERS THEN
    		return_status:=SQLSTATE||' : '||SQLERRM;
    		RAISE EXCEPTION '%',return_status;
    		RAISE NOTICE '%',return_status;

    	END;

    --- delete and insert data into mapping_data table based on hr_employee, biometric_employee_details tables (22-aug-2019)

	delete from mapping_data where data_source='MSACCESS';

	insert into mapping_data (biometric_empid,odoo_employeeid,data_source,employ_code)
	select bed.person_id,hr.id,'MSACCESS' build_cd,hr.emp_id
	from hr_employee hr, stg_biometric_data bed
	where upper(REPLACE(bed.emp_code,' ',''))=upper(REPLACE(hr.emp_id,' ',''))
	--where bed.emp_code=hr.emp_id
	and bed.emp_code!=''
	and hr.active='T'   group by  bed.person_id,hr.id, build_cd, hr.emp_id;


	--delete from hr_attendance where facility='Balaji Empire' and extract('month' from check_in) in (select max(extract ('month' from log_date_time)) from 	stg_biometric_data	where data_source='MSACCESS');
        FOR rec_stg_emp_data in l_cur_emp_data
        LOOP
        	RAISE NOTICE ' ';
        	RAISE NOTICE 'biometric emp id : %',rec_stg_emp_data.person_id;
			update 	stg_biometric_data
    						set errors_desc=NULL
    					where 	person_id=rec_stg_emp_data.person_id
						AND data_source='MSACCESS';

        	-- Calculate in & out of employee biometric data
        	FOR rec_att_base_data in
				WITH stg_data as (
					select rn ,id,person_id,direction,l_direction,data_source,log_date_time  from
					(
						select ROW_NUMBER() OVER(Order by log_date_time) rn ,id,person_id,direction,lead(direction) over (order by id ) l_direction ,data_source,log_date_time
						from stg_biometric_data
						where person_id=rec_stg_emp_data.person_id
						and log_date_time::date=rec_stg_emp_data.stg_date
						and extract('hour' from log_date_time::timestamp without time zone)::int between 5 and 23
					) a where coalesce(direction,'')!=coalesce(l_direction	,'')
					group by rn ,id,person_id,direction,l_direction,data_source,log_date_time  having NOT (rn=1 and direction='main door Out')
				) , data_checkin as (

				    SELECT 	ROW_NUMBER() OVER(Order by log_date_time) rn1 ,
							sd.person_id,
							sd.id,
							md.odoo_employeeid,
							sd.log_date_time checkin,
							date(sd.log_date_time) chkin_dt
					FROM 	stg_data sd,
							mapping_data md
					where 	sd.person_id::int=md.biometric_empid
					--AND 	sd.person_id::int=rec_stg_emp_data.person_id
					AND 	sd.direction='main door In'
					AND 	sd.data_source='MSACCESS'
					--AND 	date(sd.log_date_time)=rec_stg_emp_data.stg_date
				)
				,data_checkout as (
					SELECT 	ROW_NUMBER() OVER(Order by log_date_time) rn2 ,
							sd.person_id,
							md.odoo_employeeid,
							sd.log_date_time checkout,
							date(sd.log_date_time) chkout_dt
					FROM 	stg_data sd,
							mapping_data md
					where 	sd.person_id::int=md.biometric_empid
					--AND 	sd.person_id::int=rec_stg_emp_data.person_id
					AND 	sd.direction='main door Out'
					AND 	sd.data_source='MSACCESS'
					--AND 	date(sd.log_date_time)=rec_stg_emp_data.stg_date
				) 	select 	din.id,
							din.person_id,
							din.odoo_employeeid,
							din.checkin,
							dout.checkout,
							din.chkin_dt
					from 	data_checkin din
					LEFT JOIN data_checkout dout on (
					                                 din.person_id=dout.person_id
					                                 and din.rn1=dout.rn2
													 and din.chkin_dt=dout.chkout_dt
					                                 )
			LOOP
				BEGIN
					insert into public.hr_attendance
						(
						 employee_id
						 ,check_in
						 ,check_out
						 --,worked_hours
						 ,facility
						-- ,"date"
						)
						values
						(
						 rec_att_base_data.odoo_employeeid
						 ,rec_att_base_data.checkin::timestamptz AT TIME ZONE 'GMT'
						 ,rec_att_base_data.checkout::timestamptz AT TIME ZONE 'GMT'
						 --,extract(epoch from (rec_att_base_data.checkout::timestamp-rec_att_base_data.checkin::timestamp))/3600
						 ,p_facility_name
						 --,rec_att_base_data.chkin_dt::date
						) ;-- ON CONFLICT ON CONSTRAINT hr_attendance_employee_id_check_in_check_out_key DO NOTHING;
					RAISE NOTICE 'Employee_ID : %, Empchk_in : %,Empchk_out : % , l_inseted_values : %',rec_att_base_data.odoo_employeeid,rec_att_base_data.checkin,rec_att_base_data.checkout,l_inseted_values;
					exception
    					WHEN unique_violation THEN
    						l_error_message:='This data already available in ERP system ';
    						update 	stg_biometric_data
    						set errors_desc=l_error_message
    						where 	id=rec_att_base_data.id;
    						--WHEN SQLSTATE '23505' THEN
    						--	return_status:='This data already available in ERP system '||l_inseted_values;
    					WHEN OTHERS THEN
							--return_status:='This data already available in ERP system';
							l_error_message:=SQLSTATE||':'||SQLERRM;
							--RAISE EXCEPTION '%',return_status;
							update 	stg_biometric_data
    						set errors_desc=l_error_message
    						where 	id=rec_att_base_data.id;
				END;
			END LOOP;

        END LOOP;

    return_status:='Data Loaded Successfully ';
    exception
    WHEN OTHERS THEN
		--return_status:='This data already available in ERP system';
		return_status:=SQLSTATE||':'||SQLERRM;


    END;



  END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
