
  CREATE OR REPLACE FUNCTION public.sea_get_facilty(p_odoo_empid integer,OUT return_status character varying)
       RETURNS character varying AS
$BODY$
   BEGIN




    DECLARE
    rec_hr_att_data            	record;



BEGIN

	select CONCAT_WS(',',max(case when data_source='MSACCESS' then 'Balaji Empire' end),
	min(case	when data_source='MSSQL' then 'Cyber Ville' end)) into return_status

	from mapping_data where odoo_employeeid=p_odoo_empid
	group by odoo_employeeid;


		EXCEPTION
		WHEN OTHERS THEN
		RAISE NOTICE 'SQLError %:%',SQLSTATE,SQLERRM;
		return_status:='SQLError '||SQLSTATE||':'||SQLERRM;


    END;



  END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
