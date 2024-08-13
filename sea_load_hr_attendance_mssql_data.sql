
CREATE OR REPLACE FUNCTION public.sea_load_hr_attendance_mssql_data(facility_selected character varying,OUT return_status character varying)
      RETURNS character varying AS
$BODY$
   BEGIN

--    #variable_conflict use_variable
    DECLARE
        curtime timestamp := now();
        rec_stg_emp_data 			record;
        rec_att_base_data 			record;
        l_error_message 			character varying;

        l_cur_emp_data CURSOR IS
        select 	person_id,
        		date(log_date_time) stg_date
        from 	stg_biometric_data
		where data_source='MSSQL'
        group by person_id,
 				 date(log_date_time);

    BEGIN

	--- delete and insert data into mapping_data table based on hr_employee, biometric_employee_details tables (22-aug-2019)

	delete from mapping_data where data_source='MSSQL';

	insert into mapping_data (biometric_empid,odoo_employeeid,data_source,employ_code)
	select bed.emp_seq_id,hr.id,'MSSQL' facility,hr.emp_id --into l_emp_seq_id,l_emp_id,l_facility
	from hr_employee hr, biometric_employee_details bed
	where upper(REPLACE(bed.emp_name,' ',''))=upper(REPLACE(hr.emp_id,' ',''))
	--where bed.emp_name=hr.emp_id
	and bed.emp_name!=''
		and hr.active='T'group by bed.emp_seq_id,hr.id,facility,hr.emp_id;


    	delete from hr_attendance where facility=facility_selected and extract('month' from check_in) in (select max(extract ('month' from log_date_time)) from 	stg_biometric_data	where data_source='MSSQL');
        FOR rec_stg_emp_data in l_cur_emp_data
        LOOP

        	RAISE NOTICE ' ';
        	RAISE NOTICE 'biometric emp id : %',rec_stg_emp_data.person_id;
			update 	stg_biometric_data
    						set errors_desc=NULL
    					where 	person_id=rec_stg_emp_data.person_id
						AND data_source='MSSQL';
        	-- Calculate in & out of employee biometric data

        	FOR rec_att_base_data in


				WITH stg_data as (
					select rn ,id,person_id,direction,l_direction,data_source,log_date_time ,facility  from
					(
						select ROW_NUMBER() OVER(Order by log_date_time) rn ,id,person_id,direction,lead(direction) over (order by id ) l_direction ,data_source,log_date_time ,facility
						from stg_biometric_data
						where person_id=rec_stg_emp_data.person_id
						and log_date_time::date=rec_stg_emp_data.stg_date
						and extract('hour' from log_date_time::timestamp without time zone)::int between 5 and 23
						and coalesce(char_length(trim(errors_desc)),0)=0
						order by log_date_time
					) a where coalesce(direction,'')!=coalesce(l_direction	,'')
					group by rn ,id,person_id,direction,l_direction,data_source,log_date_time ,facility  having NOT (rn=1 and direction='out')
				) , data_checkin as (
				    SELECT 	ROW_NUMBER() OVER(Order by sd.log_date_time) rn1 ,
							sd.person_id,
							sd.id,
							md.odoo_employeeid,
							sd.log_date_time checkin,
							date(sd.log_date_time) chkin_dt,
							sd.facility
					FROM 	stg_data sd,
							mapping_data md
					where 	sd.person_id::int=md.biometric_empid
					--AND 	sd.person_id::int=rec_stg_emp_data.person_id
					AND 	sd.direction='in'
					AND 	sd.data_source='MSSQL'
					--AND 	date(sd.log_date_time)=rec_stg_emp_data.stg_date

				)
				,data_checkout as (
					SELECT 	ROW_NUMBER() OVER(Order by sd.log_date_time) rn2 ,
							sd.person_id,
							md.odoo_employeeid,
							sd.log_date_time checkout,
							date(sd.log_date_time) chkout_dt
					FROM 	stg_data sd,
							mapping_data md
					where 	sd.person_id::int=md.biometric_empid
					--AND 	sd.person_id::int=rec_stg_emp_data.person_id
					AND 	sd.direction='out'
					AND 	sd.data_source='MSSQL'
					--AND 	date(sd.log_date_time)=rec_stg_emp_data.stg_date
				) 	select 	din.id,
							din.odoo_employeeid,
							din.checkin,
							dout.checkout,
							din.facility
					from 	data_checkin din
					LEFT JOIN data_checkout dout on (
					                                 din.person_id::int=dout.person_id::int
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
						 ,worked_hours
						 ,facility
						)
						values
						(
						 rec_att_base_data.odoo_employeeid
						 ,rec_att_base_data.checkin::timestamptz AT TIME ZONE 'GMT'
						 ,rec_att_base_data.checkout::timestamptz AT TIME ZONE 'GMT'
						 ,extract(epoch from (rec_att_base_data.checkout::timestamp-rec_att_base_data.checkin::timestamp))/3600
						 ,rec_att_base_data.facility
						) ;
					RAISE NOTICE 'Employee_ID : %, Empchk_in : %,Empchk_out : %',rec_att_base_data.odoo_employeeid,rec_att_base_data.checkin,rec_att_base_data.checkout;

					exception
					WHEN unique_violation THEN
    					l_error_message:='This data already available in ERP system ';
    					update 	stg_biometric_data
    						set errors_desc=l_error_message
    					where 	id=rec_att_base_data.id;
					WHEN OTHERS THEN
						RAISE INFO 'Error Name:%', SQLERRM;
						RAISE INFO 'Error State:%', SQLSTATE;
						l_error_message:=SQLSTATE||' : '||SQLERRM;
						update 	stg_biometric_data
    						set errors_desc=l_error_message
    					where 	id=rec_att_base_data.id;
    			END;
			END LOOP;

        END LOOP;

    return_status:='Data Loaded Successfully ';


    END;


  END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
