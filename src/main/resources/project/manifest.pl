@files = (
    ['//property[propertyName="ECDefectTracking::Fortress::Cfg"]/value', 'FortressCfg.pm'],
    ['//property[propertyName="ECDefectTracking::Fortress::Driver"]/value', 'FortressDriver.pm'],
    ['//property[propertyName="createConfig"]/value', 'FortressCreateConfigForm.xml'],
    ['//property[propertyName="editConfig"]/value', 'fortressEditConfigForm.xml'],
    ['//property[propertyName="ec_setup"]/value', 'ec_setup.pl'],
	['//procedure[procedureName="LinkDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-LinkDefects.xml'],	
	['//procedure[procedureName="UpdateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-UpdateDefects.xml'],	
	['//procedure[procedureName="CreateDefects"]/propertySheet/property[propertyName="ec_parameterForm"]/value', 'ec_parameterForm-CreateDefects.xml'],	
);
