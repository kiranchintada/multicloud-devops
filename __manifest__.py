# -*- coding: utf-8 -*-
{
    'name': " SEA Biometric Integration ",

    'summary': """ SEA Biometric Integration  """,

    'description': """  This module integrates the biometric data and it shows the consolidated report """,

    'author': "Sailotech Pvt Ltd",
    'website': "http://www.Sailotech.com",
    'category': 'SEA Biometric Integration ',
    'version': '11.0',
    'depends': ['hr_attendance','base','hr','sea_popup_message','sailotech_employee_appraisal'],
    'data': [
        'security/ir.model.access.csv',
        'security/security.xml',
        'wizard/revalidate_workedhours_view.xml',
        'views/attendance_report_view.xml',
        'wizard/get_sqlserver_data_import_view.xml',
        'wizard/get_msaccess_data_import_view.xml',
        'views/mapping_data_view.xml',
        'views/biometric_attendance.xml',
        'views/configuration.xml',
        'sea_load_hr_attendance_mssql_data.sql',
        'sea_calculate_attendance_worked_hours.sql',
        'sea_calculate_leave_hours.sql',
        'sea_get_facilty.sql',
        'sea_load_hr_attendance_msaccess_data.sql',
        
    ],

}