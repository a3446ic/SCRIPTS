CREATE OR REPLACE PROCEDURE EXT.SP_SCRIPT_SAMUEL
LANGUAGE SQLSCRIPT SQL SECURITY DEFINER DEFAULT SCHEMA EXT AS
BEGIN
    DECLARE numRec INT;
    DECLARE SQL_ERROR_MESSAGE NVARCHAR(1000);
    DECLARE SQL_ERROR_CODE INT;
    DECLARE i_Tenant Number := 1689;
    DECLARE vProcedure NVARCHAR(50) := 'PRUEBAS';
    DECLARE io_contador Number := 0;
    
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		select 'exception sql' from dummy;
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (
			i_Tenant, 
			'SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: '||::SQL_ERROR_CODE, 
			vProcedure , 
			io_contador
		);
		select 'fin exception sql' from dummy;
		--RESIGNAL;
		
	END;

    -- Simulación de una situación donde queremos provocar una excepción
    numRec := -1;
    -- Verificar si numRec es negativo y lanzar una excepción en ese caso
    IF numRec < 0 THEN
	BEGIN
       	SQL_ERROR_MESSAGE := 'Se ha producido un error personalizado.';
	    SQL_ERROR_CODE := 5001; -- Código de error personalizado

        -- Llamada al procedimiento almacenado para registrar el error personalizado
        CALL EXT.LIB_GLOBAL_CESCE:w_debug (
    	    i_Tenant,
	        'SQL_ERROR_MESSAGE: ' || IFNULL(SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || SQL_ERROR_CODE,
    	    vProcedure,
            io_contador
	    );
    END;

    -- Generar un error intencional para provocar la excepción
    SELECT 1 / 0 INTO numRec FROM DUMMY;
      
    END IF;
 END;



--LLAMADA PROCEDIMIENTO
CALL EXT.SP_SCRIPT_SAMUEL;

select * from ext.cse_debug where cast(datetime as date) = '2024-06-20';
delete from ext.cse_debug where PROCESO = 'PRUEBAS' AND cast(datetime as date) = '2024-06-20';
--BORRAR PROCEDIMIENTO PRUEBAS
--DROP PROCEDURE EXT.SP_SCRIPT_SAMUEL