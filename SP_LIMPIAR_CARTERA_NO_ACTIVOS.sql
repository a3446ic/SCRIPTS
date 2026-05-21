CREATE OR REPLACE PROCEDURE EXT.SP_LIMPIAR_CARTERA_NO_ACTIVOS()
LANGUAGE SQLSCRIPT AS
BEGIN

	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_NAME;    
    DECLARE v_version VARCHAR2(10) := '1.00';    
    DECLARE v_idproceso INTEGER := 0;
    DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL_CESCE:getTenantID();    
    DECLARE v_contFilas INT := 0;
    
    ---------------------------------------------------------------------------------------------------------------------------------------
    --CONTROLADOR DE EXCEPCIONES
    ---------------------------------------------------------------------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'SQL ERROR_MESSAGE: ' ||
					IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE || ' v_contFilas ' || v_contFilas, v_proc_name, v_idproceso);
	END;
	---------------------------------------------------------------------------------------------------------------------------------------	


	CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Version: ' || v_version || ' - Procedure starting...' , v_proc_name, v_idproceso);
	CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'INICIO LIMPIEZA CARTERA NO ACTIVOS' , v_proc_name, v_idproceso);
	
    IF NOT EXISTS (SELECT * FROM SYS.TABLES WHERE schema_name = 'EXT' AND table_name = 'CARTERA_NOACTIVO') THEN
        CREATE TABLE EXT.CARTERA_NOACTIVO
            LIKE EXT.CARTERA;
    END IF;
    

    INSERT INTO EXT.CARTERA_NOACTIVO
        SELECT * FROM EXT.CARTERA c
        WHERE c.ACTIVO = 0;
    
    v_contFilas := ::ROWCOUNT;
    COMMIT;

    CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Insert into EXT.CARTERA_NOACTIVO: ' || v_contFilas, v_proc_name, v_idproceso);

    DELETE FROM EXT.CARTERA c
        WHERE c.ACTIVO = 0;

    v_contFilas := ::ROWCOUNT;
    COMMIT;

    CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Delete from EXT.CARTERA: ' || v_contFilas, v_proc_name, v_idproceso);

    CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Fin del proceso.', v_proc_name, v_idproceso);

END