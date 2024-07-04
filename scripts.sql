--Comprobar si existe un procedimiento
SELECT *
FROM sys.procedures
WHERE procedure_name = 'SP_CARGAR_POLIZAS_TRASPASO';

--Buscar cadena de texto en procedimientos y funciones de la BBDD
do begin
	declare cadena varchar(255);
	cadena := 'poliza';
	
	select 'PROCEDURE' AS Tipo,schema_name,procedure_name 
	from sys.procedures
	where definition like '%'|| cadena || '%'
	union
	select 'FUNCION' AS Tipo,schema_name,function_name
	from sys.functions
	where definition like '%'|| cadena || '%';
end;

--Tabla virtual EXT.VT_PipelineRuns --> TCMP.CS_PLRUN

--version sap hana
VERSION
2.00.072.00.1706869717

