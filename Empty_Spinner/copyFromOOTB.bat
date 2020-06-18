@echo off

echo 本copyFromOOTB工具是为了加快你从OOTB等其他schema中拷贝数据结构的速度和准确性。(www.top-gun.cn)


setlocal

set /p file2=  请输入OOTB schema的绝对路径，如c:\OOTB:

:A
set /p selection=  请选择Schema类型(1:attribute; 2:Channel, 3:Command, 4:Dimension, 5:Group, 6:Inquiry, 7:Menu, 8:Policy, 9:Portal, 10:Program, 11:Property, 12:Relationship, 13:Role, 14:Rule, 15:Table, 16:Trigger, 17:Type, 18:Webform):

set /p keyword=  请输入AO名称（精确名称):

rem treat for schema

if %selection%==1 findstr /b /c:"%keyword%" %file2%\Business\SpinnerAttributeData.xls >> .\Business\SpinnerAttributeData.xls

if %selection%==2 findstr /b /c:"%keyword%" %file2%\Business\SpinnerChannelData.xls >> .\Business\SpinnerChannelData.xls

if %selection%==3 findstr /b /c:"%keyword%" %file2%\Business\SpinnerCommandData.xls >> .\Business\SpinnerCommandData.xls

if %selection%==4 findstr /b /c:"%keyword%" %file2%\Business\SpinnerCommSpinnerDimensionData.xls >> .\Business\SpinnerCommSpinnerDimensionData.xls

if %selection%==4 findstr /b /c:"%keyword%" %file2%\Business\SpinnerDimensionUnitData.xls >> .\Business\SpinnerDimensionUnitData.xls

if %selection%==5 findstr /b /c:"%keyword%" %file2%\Business\SpinnerGroupData.xls >> .\Business\SpinnerGroupData.xls

if %selection%==6 findstr /b /c:"%keyword%" %file2%\Business\SpinnerInquiryData.xls >> .\Business\SpinnerInquiryData.xls

if %selection%==7 findstr /b /c:"%keyword%"%file2%\Business\SpinnerMenuData.xls >> .\Business\SpinnerMenuData.xls

if %selection%==8 findstr /b /c:"%keyword%" %file2%\Business\SpinnerPolicyData.xls >> .\Business\SpinnerPolicyData.xls

if %selection%==8 findstr /b /c:"%keyword%" %file2%\Business\SpinnerPolicyStateData.xls >> .\Business\SpinnerPolicyStateData.xls

if %selection%==9 findstr /b /c:"%keyword%" %file2%\Business\SpinnerPortalData.xls >> .\Business\SpinnerPortalData.xls

if %selection%==10 findstr /b /c:"%keyword%" %file2%\Business\SpinnerProgramData.xls >> .\Business\SpinnerProgramData.xls

if %selection%==11 findstr /c:"%keyword%" %file2%\Business\SpinnerPropertyData.xls >> .\Business\SpinnerPropertyData.xls

if %selection%==12 findstr /b /c:"%keyword%" %file2%\Business\SpinnerRelationshipData.xls >> .\Business\SpinnerRelationshipData.xls

if %selection%==13 findstr /b /c:"%keyword%" %file2%\Business\SpinnerRoleData.xls >> .\Business\SpinnerRoleData.xls

if %selection%==14 findstr /b /c:"%keyword%" %file2%\Business\SpinnerRuleData.xls >> .\Business\SpinnerRuleData.xls

if %selection%==15 findstr /b /c:"%keyword%" %file2%\Business\SpinnerTableData.xls >> .\Business\SpinnerTableData.xls

if %selection%==15 findstr /b /c:"%keyword%" %file2%\Business\SpinnerTableColumnData.xls >> .\Business\SpinnerTableColumnData.xls

if %selection%==16 findstr /c:"%keyword%" %file2%\Business\SpinnerTriggerData.xls >> .\Business\SpinnerTriggerData.xls

if %selection%==17 findstr /b /c:"%keyword%" %file2%\Business\SpinnerTypeData.xls >> .\Business\SpinnerTypeData.xls

if %selection%==18 findstr /b /c:"%keyword%" %file2%\Business\SpinnerWebFormData.xls >> .\Business\SpinnerWebFormData.xls

if %selection%==18 findstr /b /c:"%keyword%" %file2%\Business\SpinnerWebFormFieldData.xls >> .\Business\SpinnerWebFormFieldData.xls

rem treat for policy files

if %selection%==8  copy "%file2%\Business\Policy\%keyword%*" .\Business\Policy /y

rem treat for rule files

if %selection%==14 copy "%file2%\Business\Rule\%keyword%*" .\Business\Rule /y

rem treat for JPO files

if %selection%==10 copy "%file2%\Business\SourceFiles\%keyword%*" .\Business\SourceFiles  /y

echo 拷贝完成，具体的更改请到目标目录中确认, 通常情况下,它是以SVN显示红色为标示。


pause 
goto A