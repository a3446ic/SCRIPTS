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

--Obtener fecha actual
SELECT 

--ESCRIBIR LOG
CALL LIB_GLOBAL_CESCE :w_debug (
        i_Tenant,
        'Fichero MOVIMIENTO_CARTERA con '  || to_varchar(numLineasFichero) || ' lineas distintas. Insertando en tabla EXT_MOVIMIENTO_CARTERA_CREDITO_HIST',
        cReportTable,
        io_contador
    );


-- LOTES
DO BEGIN
    DECLARE BATCH_SIZE INT := 1000;
    DECLARE OFFSET INT := 0;
    DECLARE TOTAL_COUNT INT;
    DECLARE BATCH_ID INT := 1;

    -- Obtener el número total de registros a procesar
    SELECT COUNT(*) INTO TOTAL_COUNT FROM EXT.EXT_CARGA_MASIVA_HIST;

    WHILE OFFSET < TOTAL_COUNT DO
        BEGIN
            DECLARE EXIT HANDLER FOR SQLEXCEPTION
            BEGIN
                -- Registrar el error
               SELECT 'ERROR' FROM DUMMY;
               -- LEAVE;
            END;

            -- Procesar un lote de datos
            SELECT BATCH_ID,ROW_NUMBER() OVER (ORDER BY CREATEDATE ) AS row_num,*
            FROM EXT.EXT_CARGA_MASIVA_HIST
            ORDER BY CREATEDATE
            LIMIT :BATCH_SIZE OFFSET :OFFSET;            
            

            -- Incrementar el offset para el siguiente lote
            OFFSET := OFFSET + BATCH_SIZE;
            -- Incrementar el ID del lote
            BATCH_ID := BATCH_ID + 1;
        END;
    END WHILE;
    
    SELECT * FROM EXT.CSE_DEBUG 
    WHERE 1=1
    -- AND PROCESO LIKE '%CARGA_MASIVA%' 
    --AND CAST(DATETIME AS DATE) = CAST('2024-07-12' AS DATE)
    and text not like '%Insertados%'
    and datetime >='2024-07-15 11:51:12.073000000'
    AND TEXT LIKE '%1689_MVTEST_%';
END;
