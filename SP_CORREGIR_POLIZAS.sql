CREATE OR REPLACE PROCEDURE EXT.SP_CORREGIR_POLIZAS(in v_filename VARCHAR(250))
LANGUAGE SQLSCRIPT AS
BEGIN

	DECLARE v_proc_name VARCHAR2(50) := ::CURRENT_OBJECT_NAME;    
    DECLARE v_version VARCHAR2(10) := '0.1';
    DECLARE v_num_rows INTEGER := 0;
    DECLARE v_log_count INTEGER := 0;
    DECLARE v_idproceso INTEGER := 0;
    DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL_CESCE:getTenantID();
    DECLARE v_tipoError VARCHAR(120);
    DECLARE v_codMediador VARCHAR(4);
    DECLARE v_codSubclave VARCHAR(4);
    DECLARE v_batchname VARCHAR(250);
    DECLARE v_totalFilas INT;
    DECLARE v_contFilas INT := 0;
    DECLARE v_numPoliza BIGINT;
    DECLARE v_numAnualidad INT;
    DECLARE v_numFianza BIGINT;
    DECLARE v_fechaVencimiento DATE;
    DECLARE v_fechaEfecto DATE;
    DECLARE v_motivo VARCHAR(50);
    DECLARE v_codMediador_modificar VARCHAR(9);
    DECLARE v_fecha_vencimiento_modificar DATE;
    DECLARE v_fecha_efecto_modificar DATE;
    DECLARE v_totalFilasCorregidas BIGINT;
    -- DECLARE V_NUM_POLIZA_TEST BIGINT = 22831;
    
    ---------------------------------------------------------------------------------------------------------------------------------------
    --CONTROLADOR DE EXCEPCIONES
    ---------------------------------------------------------------------------------------------------------------------------------------
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'SQL ERROR_MESSAGE: ' ||
					IFNULL(::SQL_ERROR_MESSAGE,'') || '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE || ' v_numPoliza ' || v_numPoliza || ' v_numFianza ' || v_numFianza || ' v_contFilas ' || v_contFilas, v_proc_name, v_idproceso);
	END;
	---------------------------------------------------------------------------------------------------------------------------------------
	
	CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Version: ' || v_version || ' - Procedure starting...' , v_proc_name, v_idproceso);
	CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'INICIO PÓLIZAS DE CRÉDITO CON ERROR' , v_proc_name, v_idproceso);
	
	
	IF EXISTS(SELECT 1 FROM DUMMY WHERE UPPER(:v_filename) LIKE '%MVCAR%') THEN
	---------------------------------------------------------------------------------------------------------------------------------------
    --POLIZAS DE CREDITO (MVCAR)
    ---------------------------------------------------------------------------------------------------------------------------------------
    
	
		SELECT COUNT(*) INTO v_totalFilas FROM EXT.GET_POLIZAS_CREDITO_ERROR_FICHERO(:v_filename);
		
		
		
		
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Registros de CREDITO con error: ' || v_totalFilas, v_proc_name, v_idproceso);
		
		-- TEST
		C_MOTIVOS_ERROR_CREDITO = SELECT ROW_NUMBER() OVER () AS NUM_FILA,* FROM EXT.GET_POLIZAS_CREDITO_ERROR_FICHERO(:v_filename);
		
		TEMP_DISTINTA_SUBCLAVE = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO 
			WHERE MOTIVO  = 'MEDIADOR DISTINTO EN CARTERA';
			
	
	
		UPDATE C
		SET COD_SUBCLAVE = RIGHT(T.IDMEDIADOR,4)
			,MODIF_USER = 'MANUAL DISTINTA_SUBCLAVE'
			, MODIF_DATE = CURRENT_TIMESTAMP
		FROM EXT.CARTERA C
		INNER JOIN :TEMP_DISTINTA_SUBCLAVE T ON C.NUM_POLIZA = T.NUM_POLIZA AND C.NUM_ANUALIDAD = T.ANUALIDAD
				AND C.COD_MEDIADOR = SUBSTRING(T.IDMEDIADOR,1,4)  AND LPAD(C.IDMODALIDAD,3,0) = LPAD(T.IDMODALIDAD,3,0)
		WHERE C.ACTIVO > 0 
			AND RAMO = 'CREDITO'
			;
		
		
		
			
		TEMP_DISTINTA_FECHA_EFECTO = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO 
			WHERE MOTIVO  = 'FECHA EFECTO DISTINTA EN CARTERA';
			
		
		UPDATE C
		SET FECHA_EFECTO = T.FECHA_EFECTO
			, MODIF_USER = 'MANUAL DISTINTA_FECHA_EFECTO'
			, MODIF_DATE = CURRENT_TIMESTAMP
		FROM EXT.CARTERA C
		INNER JOIN :TEMP_DISTINTA_FECHA_EFECTO T ON C.NUM_POLIZA = T.NUM_POLIZA AND C.NUM_ANUALIDAD = T.ANUALIDAD
				AND C.COD_MEDIADOR = SUBSTRING(T.IDMEDIADOR,1,4)   AND C.COD_SUBCLAVE = RIGHT(T.IDMEDIADOR,4) AND LPAD(C.IDMODALIDAD,3,0) = LPAD(T.IDMODALIDAD,3,0)
		WHERE C.ACTIVO > 0 
			AND C.RAMO = 'CREDITO'
			;
		
		
		UPDATE C
		SET FECHA_VENCIMIENTO = CASE
			WHEN CRT_ANT.FECHA_VENCIMIENTO <> ADD_DAYS(T.FECHA_EFECTO,-1) THEN ADD_DAYS(T.FECHA_EFECTO,-1)
			END 
			, MODIF_USER = 'MANUAL DISTINTA_FECHA_EFECTO'
			, MODIF_DATE = CURRENT_TIMESTAMP
		FROM EXT.CARTERA C
		INNER JOIN :TEMP_DISTINTA_FECHA_EFECTO T ON C.NUM_POLIZA = T.NUM_POLIZA 
				AND C.COD_MEDIADOR = SUBSTRING(T.IDMEDIADOR,1,4)   AND C.COD_SUBCLAVE = RIGHT(T.IDMEDIADOR,4) AND LPAD(C.IDMODALIDAD,3,0) = LPAD(T.IDMODALIDAD,3,0)
		LEFT JOIN (SELECT *
						,ROW_NUMBER() OVER (PARTITION BY CR.NUM_POLIZA, CR.COD_MEDIADOR, CR.COD_SUBCLAVE ORDER BY CR.NUM_ANUALIDAD DESC) AS RN
					FROM EXT.CARTERA CR WHERE CR.RAMO = 'CREDITO' AND CR.ACTIVO = 1
        	        ) CRT_ANT ON C.NUM_POLIZA = CRT_ANT.NUM_POLIZA 
        	        	AND C.COD_MEDIADOR = CRT_ANT.COD_MEDIADOR 
        	        	AND C.COD_SUBCLAVE = CRT_ANT.COD_SUBCLAVE 
        	        	AND C.NUM_ANUALIDAD = CRT_ANT.NUM_ANUALIDAD 
        	        	AND LPAD(C.IDMODALIDAD,3,0) = LPAD(CRT_ANT.IDMODALIDAD,3,0)
        	        	AND CRT_ANT.RN = 2
		WHERE C.ACTIVO > 0 
			AND C.RAMO = 'CREDITO'
			AND 1 = (CASE WHEN EXISTS (SELECT 1 FROM (SELECT ROW_NUMBER() OVER (PARTITION BY CR.NUM_POLIZA, CR.COD_MEDIADOR, CR.COD_SUBCLAVE ORDER BY CR.NUM_ANUALIDAD DESC) AS RN
					FROM EXT.CARTERA CR WHERE CR.RAMO = 'CREDITO' AND CR.ACTIVO = 1
        	        AND C.NUM_POLIZA = CR.NUM_POLIZA 
        	        	AND C.COD_MEDIADOR = CR.COD_MEDIADOR 
        	        	AND C.COD_SUBCLAVE = CR.COD_SUBCLAVE 
        	        	) X WHERE X.RN = 2)
        	        	THEN 1
        	        	ELSE 0
        	        	END)
        	 AND 1 = (CASE WHEN CRT_ANT.FECHA_VENCIMIENTO <> ADD_DAYS(T.FECHA_EFECTO,-1) THEN 1
        				ELSE 0 END)
        	  AND CRT_ANT.RN = 2;
        	  
        C_MOTIVOS_ERROR_CREDITO = SELECT ROW_NUMBER() OVER () AS NUM_FILA,* FROM EXT.GET_POLIZAS_CREDITO_ERROR_FICHERO(:v_filename);	
        
        TEMP_DISTINTA_FECHA_VENCIMIENTO = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO 
			WHERE MOTIVO  = 'FECHA VENCIMIENTO DISTINTA EN CARTERA';
			
		
		UPDATE C
		SET FECHA_VENCIMIENTO = T.FECHA_VENCIMIENTO
			, MODIF_USER = 'MANUAL DISTINTA_FECHA_VENCIMIENTO'
			, MODIF_DATE = CURRENT_TIMESTAMP
		FROM EXT.CARTERA C
		INNER JOIN :TEMP_DISTINTA_FECHA_VENCIMIENTO T ON C.NUM_POLIZA = T.NUM_POLIZA AND C.NUM_ANUALIDAD = T.ANUALIDAD
				AND C.COD_MEDIADOR = SUBSTRING(T.IDMEDIADOR,1,4)   AND C.COD_SUBCLAVE = RIGHT(T.IDMEDIADOR,4) AND LPAD(C.IDMODALIDAD,3,0) = LPAD(T.IDMODALIDAD,3,0)
		WHERE C.ACTIVO > 0 
			AND C.RAMO = 'CREDITO'
			;	  		  
        
		
	
		SELECT COUNT(*) INTO v_totalFilasCorregidas FROM EXT.GET_POLIZAS_CREDITO_ERROR_FICHERO(:v_filename);
	
		
		
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Registros corregidos : ' || v_totalFilas - v_totalFilasCorregidas , v_proc_name, v_idproceso);
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'FIN PÓLIZAS DE CRÉDITO CON ERROR' , v_proc_name, v_idproceso);
		
		
		C_MOTIVOS_ERROR_CREDITO_NO_MODIFICADAS = SELECT ROW_NUMBER() OVER () AS NUM_FILA,* FROM EXT.GET_POLIZAS_CREDITO_ERROR_FICHERO(:v_filename);
		
		TEMP_DISTINTA_SUBCLAVE_NO_MODIFICADAS = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO_NO_MODIFICADAS 
			WHERE MOTIVO  = 'MEDIADOR DISTINTO EN CARTERA';
			
		TEMP_DISTINTA_FECHA_VENCIMIENTO_NO_MODIFICADAS = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO_NO_MODIFICADAS 
			WHERE MOTIVO  = 'FECHA VENCIMIENTO DISTINTA EN CARTERA';
		
		TEMP_DISTINTA_FECHA_EFECTO_NO_MODIFICADAS = SELECT *
			FROM :C_MOTIVOS_ERROR_CREDITO_NO_MODIFICADAS 
			WHERE MOTIVO  = 'FECHA EFECTO DISTINTA EN CARTERA';
		
		TEMP_NO_MODIFICADOS = SELECT ROW_NUMBER() OVER () AS NUM_FILA, *
		FROM (
			
			SELECT 'DISTINTO MEDIADOR' MOTIVO, C.NUM_POLIZA, C.NUM_ANUALIDAD, C.COD_MEDIADOR, C.COD_SUBCLAVE, TS.IDMEDIADOR MEDIADOR_A_MODIFICAR,C.FECHA_VENCIMIENTO,C.FECHA_EFECTO
			FROM EXT.CARTERA C INNER JOIN :TEMP_DISTINTA_SUBCLAVE_NO_MODIFICADAS TS ON C.NUM_POLIZA = TS.NUM_POLIZA AND C.NUM_ANUALIDAD = TS.ANUALIDAD
				AND LPAD(C.IDMODALIDAD,3,0) = LPAD(TS.IDMODALIDAD,3,0)
			UNION ALL
			SELECT 'DISTINTA FECHA VENCIMIENTO' MOTIVO, C.NUM_POLIZA, C.NUM_ANUALIDAD, C.COD_MEDIADOR, C.COD_SUBCLAVE, TS.IDMEDIADOR MEDIADOR_A_MODIFICAR,TS.FECHA_VENCIMIENTO,C.FECHA_EFECTO
			FROM EXT.CARTERA C INNER JOIN :TEMP_DISTINTA_FECHA_VENCIMIENTO_NO_MODIFICADAS TS ON C.NUM_POLIZA = TS.NUM_POLIZA AND C.NUM_ANUALIDAD = TS.ANUALIDAD
				AND LPAD(C.IDMODALIDAD,3,0) = LPAD(TS.IDMODALIDAD,3,0)
			UNION ALL
			SELECT 'DISTINTA FECHA EFECTO' MOTIVO, C.NUM_POLIZA, C.NUM_ANUALIDAD, C.COD_MEDIADOR, C.COD_SUBCLAVE, TS.IDMEDIADOR MEDIADOR_A_MODIFICAR,C.FECHA_VENCIMIENTO,TS.FECHA_EFECTO
			FROM EXT.CARTERA C INNER JOIN :TEMP_DISTINTA_FECHA_EFECTO_NO_MODIFICADAS TS ON C.NUM_POLIZA = TS.NUM_POLIZA AND C.NUM_ANUALIDAD = TS.ANUALIDAD
				AND LPAD(C.IDMODALIDAD,3,0) = LPAD(TS.IDMODALIDAD,3,0)
				);
		
	
		
		SELECT COUNT(*) INTO v_totalFilas FROM :TEMP_NO_MODIFICADOS;
		
		FOR v_contFilas IN 1 .. v_totalFilas DO
			
			SELECT NUM_POLIZA, MOTIVO, MEDIADOR_A_MODIFICAR, COD_MEDIADOR,COD_SUBCLAVE,FECHA_VENCIMIENTO,FECHA_EFECTO
			INTO v_numPoliza, v_motivo, v_codMediador_modificar, v_codMediador, v_codSubclave,v_fecha_vencimiento_modificar,v_fecha_efecto_modificar
			FROM :TEMP_NO_MODIFICADOS
			WHERE NUM_FILA = v_contFilas;
		
			IF v_motivo = 'DISTINTO MEDIADOR' THEN
			
				CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'POLIZA NO MODIFICADA : ' || v_numPoliza || ' - MOTIVO: ' || v_motivo ||' MEDIADOR  A MODIFICAR: ' || v_codMediador_modificar || ' NO SE MODIFICA POR TENER DISTINTO MEDIADOR: ' || v_codMediador||'-'||v_codSubclave , v_proc_name, v_idproceso);
			END IF;
			IF v_motivo = 'DISTINTA FECHA VENCIMIENTO' THEN
			
				CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'POLIZA NO MODIFICADA : ' || v_numPoliza || ' - MOTIVO: ' || v_motivo ||' FECHA VENCIMIENTO: ' || v_codMediador_modificar || ' NO SE MODIFICA POR TENER DISTINTO MEDIADOR: ' || v_codMediador||'-'||v_codSubclave , v_proc_name, v_idproceso);
			END IF;
			IF v_motivo = 'DISTINTA FECHA EFECTO' THEN
			
				CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'POLIZA NO MODIFICADA : ' || v_numPoliza || ' - MOTIVO: ' || v_motivo ||' FECHA EFECTO: ' || v_codMediador_modificar || ' NO SE MODIFICA POR TENER DISTINTO MEDIADOR: ' || v_codMediador||'-'||v_codSubclave , v_proc_name, v_idproceso);
			END IF;
			
		END FOR;
		
		---------------------------------------------------------------------------------------------------------------------------------------
		
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, '----------------------------------------------' , v_proc_name, v_idproceso);
	
	ELSE
		---------------------------------------------------------------------------------------------------------------------------------------
    	--POLIZAS DE CAUCION (MVFID)
    	---------------------------------------------------------------------------------------------------------------------------------------
    	
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'INICIO PÓLIZAS DE CAUCIÓN CON ERROR' , v_proc_name, v_idproceso);
		v_totalFilas := 0;
		v_totalFilasCorregidas := 0;
		
		-- TEST
		
		SELECT COUNT(*) INTO v_totalFilas FROM EXT.GET_POLIZAS_CAUCION_ERROR_FICHERO(:v_filename);
	
		
		
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Registros de CAUCION con error: ' || v_totalFilas, v_proc_name, v_idproceso);
		
		-- TEST
		C_MOTIVOS_ERROR_CAUCION = SELECT ROW_NUMBER() OVER () AS NUM_FILA,* FROM EXT.GET_POLIZAS_CAUCION_ERROR_FICHERO(:v_filename);
		-- PRD
		-- C_MOTIVOS_ERROR_CAUCION = SELECT ROW_NUMBER() OVER () AS NUM_FILA,* FROM EXT.GET_POLIZAS_CAUCION_ERROR();
		
				
		v_totalFilas = RECORD_COUNT(:C_MOTIVOS_ERROR_CAUCION);
		
		
		v_contFilas:= 0;
		
		FOR v_contFilas IN 1 .. v_totalFilas DO
		
			SELECT MOTIVO,NUM_POLIZA,NUM_FIANZA,SUBSTRING(IDMEDIADOR,1,4),SUBSTRING(IDMEDIADOR,6,4),BATCHNAME INTO v_tipoError,v_numPoliza,v_numFianza,v_codMediador,v_codSubclave,v_batchname 
			FROM :C_MOTIVOS_ERROR_CAUCION WHERE NUM_FILA = v_contFilas;
			IF v_tipoError = 'MEDIADOR DISTINTO EN CARTERA' THEN
				
				IF v_codMediador <> '0000' OR v_codSubclave <> '0000'  THEN
				 
					CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'POLIZA : ' || v_numPoliza || ' FIANZA ' || v_numFianza ||' con MEDIADOR ' || v_codMediador || ' SE MODIFICA POR TENER DISTINTO MEDIADOR (DISTINTO ''0000'')' , v_proc_name, v_idproceso);
					UPDATE EXT.CARTERA SET COD_MEDIADOR = v_codMediador, COD_SUBCLAVE = v_codSubclave, MODIF_USER = 'MANUAL SP_CORREGIR_POLIZAS', MODIF_DATE = CURRENT_TIMESTAMP
					WHERE NUM_POLIZA = v_numPoliza AND NUM_FIANZA = v_numFianza AND ACTIVO = 1;
				END IF;
				
			END IF;
		END FOR;
		
		-- TEST
		SELECT COUNT(*) INTO v_totalFilasCorregidas FROM EXT.GET_POLIZAS_CAUCION_ERROR_FICHERO(:v_filename);
		-- PRD
		-- SELECT COUNT(*) INTO v_totalFilasCorregidas FROM EXT.GET_POLIZAS_CAUCION_ERROR();
		
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Registros corregidos : ' || v_totalFilas - v_totalFilasCorregidas , v_proc_name, v_idproceso);
		CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'FIN PÓLIZAS DE CAUCIÓN CON ERROR' , v_proc_name, v_idproceso);
		---------------------------------------------------------------------------------------------------------------------------------------
		
		
	
		
	END IF;
	
	CALL EXT.LIB_GLOBAL_CESCE:w_debug (v_idtenant, 'Fin del proceso.', v_proc_name, v_idproceso);

END