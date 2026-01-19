-- ============================================================================
-- Benjamin Che - Sumativa 1
-- ============================================================================

-- Variable Bind para la fecha de proceso
VARIABLE b_fecha_proceso DATE;

-- Inicialización de la fecha de proceso con la fecha actual del sistema
EXECUTE :b_fecha_proceso := SYSDATE;

SET SERVEROUTPUT ON;

DECLARE
    -- ========================================================================
    -- SECCIÓN DE DECLARACIÓN DE VARIABLES
    -- ========================================================================
    
    -- Variables usando %TYPE para datos del empleado
    v_numrun_emp        empleado.numrun_emp%TYPE;           -- RUN del empleado
    v_dvrun_emp         empleado.dvrun_emp%TYPE;            -- Dígito verificador
    v_pnombre_emp       empleado.pnombre_emp%TYPE;          -- Primer nombre
    v_appaterno_emp     empleado.appaterno_emp%TYPE;        -- Apellido paterno
    v_id_estado_civil   empleado.id_estado_civil%TYPE;      -- ID Estado civil
    v_sueldo_base       empleado.sueldo_base%TYPE;          -- Sueldo base
    v_fecha_contrato    empleado.fecha_contrato%TYPE;       -- Fecha de contrato
    v_fecha_nac         empleado.fecha_nac%TYPE;            -- Fecha de nacimiento
    
    -- Variable para nombre del estado civil
    v_nombre_est_civil  estado_civil.nombre_estado_civil%TYPE;
    
    -- Variables para construcción de usuario y clave
    v_nombre_usuario    VARCHAR2(50);                       -- Nombre de usuario generado
    v_clave_usuario     VARCHAR2(50);                       -- Clave generada
    v_nombre_completo   VARCHAR2(200);                      -- Nombre completo
    
    -- Variables auxiliares para cálculos
    v_letra_civil       CHAR(1);                            -- Primera letra estado civil
    v_tres_letras       VARCHAR2(3);                        -- Tres primeras letras nombre
    v_largo_nombre      NUMBER(2);                          -- Largo del primer nombre
    v_ultimo_digito_sueldo NUMBER(1);                       -- Último dígito sueldo
    v_anios_trabajados  NUMBER(3);                          -- Años trabajados
    v_sufijo_anios      VARCHAR2(1);                        -- 'X' si < 10 años
    
    -- Variables para construcción de clave
    v_tercer_digito_run NUMBER(1);                          -- Tercer dígito del RUN
    v_anio_nac_mas2     NUMBER(4);                          -- Año nacimiento + 2
    v_ultimos_3_sueldo  NUMBER(3);                          -- Últimos 3 dígitos sueldo - 1
    v_dos_letras_ap     VARCHAR2(2);                        -- Dos letras apellido según regla
    v_mes_anio_actual   VARCHAR2(6);                        -- MMYYYY formato
    
    -- Variables de control
    v_contador          NUMBER(3) := 0;                     -- Contador de iteraciones
    v_total_empleados   NUMBER(3) := 0;                     -- Total esperado
    
BEGIN
    -- ========================================================================
    -- PASO 0: CONTAR TOTAL DE EMPLEADOS A PROCESAR
    -- ========================================================================
    SELECT COUNT(*) INTO v_total_empleados
    FROM empleado
    WHERE id_emp BETWEEN 100 AND 320;
    
    -- ========================================================================
    -- TRUNCAR TABLA USUARIO_CLAVE ANTES DE COMENZAR
    -- Permite ejecutar el bloque múltiples veces sin duplicados
    -- ========================================================================
    EXECUTE IMMEDIATE 'TRUNCATE TABLE USUARIO_CLAVE';
    
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('INICIO DE GENERACIÓN DE USUARIOS Y CLAVES');
    DBMS_OUTPUT.PUT_LINE('=================================================');
    DBMS_OUTPUT.PUT_LINE('Fecha de proceso: ' || TO_CHAR(:b_fecha_proceso, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('Total de empleados a procesar: ' || v_total_empleados);
    DBMS_OUTPUT.PUT_LINE('');
    
    -- ========================================================================
    -- CICLO PRINCIPAL: PROCESAR EMPLEADOS DEL 100 AL 320
    -- ========================================================================
    FOR v_id_empleado IN 100..320 LOOP
        
        BEGIN
            -- ================================================================
            -- SENTENCIA SQL 1: RECUPERAR DATOS DEL EMPLEADO
            -- Descripción: Consulta que obtiene todos los datos necesarios del 
            --              empleado para generar usuario y clave.
            -- Propósito: Evitar múltiples consultas SELECT mejorando performance
            -- ================================================================
            SELECT e.numrun_emp, 
                   e.dvrun_emp, 
                   e.pnombre_emp, 
                   e.appaterno_emp, 
                   e.id_estado_civil,
                   e.sueldo_base,
                   e.fecha_contrato,
                   e.fecha_nac,
                   ec.nombre_estado_civil
            INTO   v_numrun_emp,
                   v_dvrun_emp,
                   v_pnombre_emp,
                   v_appaterno_emp,
                   v_id_estado_civil,
                   v_sueldo_base,
                   v_fecha_contrato,
                   v_fecha_nac,
                   v_nombre_est_civil
            FROM   empleado e
            JOIN   estado_civil ec ON e.id_estado_civil = ec.id_estado_civil
            WHERE  e.id_emp = v_id_empleado;
            
            -- ================================================================
            -- PASO 2: GENERAR NOMBRE DE USUARIO
            -- ================================================================
            
            -- SENTENCIA PL/SQL 1: Extraer primera letra del estado civil
            -- Descripción: Convierte a minúscula la primera letra del estado civil
            -- Propósito: Cumplir con formato de usuario según reglas de negocio
            v_letra_civil := LOWER(SUBSTR(v_nombre_est_civil, 1, 1));
            
            -- 2. Tres primeras letras del primer nombre
            v_tres_letras := SUBSTR(v_pnombre_emp, 1, 3);
            
            -- 3. Largo del primer nombre
            v_largo_nombre := LENGTH(v_pnombre_emp);
            
            -- SENTENCIA PL/SQL #2: Calcular último dígito del sueldo base
            -- Descripción: Obtiene el último dígito usando operador módulo 10
            -- Propósito: Incorporar dato del sueldo en el nombre de usuario
            v_ultimo_digito_sueldo := MOD(v_sueldo_base, 10);
            
            -- 5. Años trabajados en la empresa (redondeado a entero)
            v_anios_trabajados := ROUND(MONTHS_BETWEEN(:b_fecha_proceso, v_fecha_contrato) / 12);
            
            -- 6. Sufijo 'X' si lleva menos de 10 años
            IF v_anios_trabajados < 10 THEN
                v_sufijo_anios := 'X';
            ELSE
                v_sufijo_anios := '';
            END IF;
            
            -- Construcción del nombre de usuario
            v_nombre_usuario := v_letra_civil || 
                               v_tres_letras || 
                               v_largo_nombre || 
                               '*' || 
                               v_ultimo_digito_sueldo || 
                               v_dvrun_emp || 
                               v_anios_trabajados ||
                               v_sufijo_anios;
            
            -- ================================================================
            -- PASO 3: GENERAR CLAVE DE USUARIO
            -- ================================================================
            
            -- 1. Tercer dígito del RUN
            v_tercer_digito_run := TO_NUMBER(SUBSTR(TO_CHAR(v_numrun_emp), 3, 1));
            
            -- 2. Año de nacimiento aumentado en 2
            v_anio_nac_mas2 := EXTRACT(YEAR FROM v_fecha_nac) + 2;
            
            -- SENTENCIA PL/SQL 3: Calcular últimos 3 dígitos del sueldo - 1
            -- Descripción: Extrae los últimos 3 dígitos del sueldo y resta 1
            -- Propósito: Generar componente numérico único para la clave
            v_ultimos_3_sueldo := MOD(ROUND(v_sueldo_base), 1000) - 1;
            
            -- 4. Dos letras del apellido paterno según estado civil
            CASE UPPER(v_nombre_est_civil)
                WHEN 'CASADO' THEN
                    -- Casado: dos primeras letras
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, 1, 2));
                WHEN 'ACUERDO DE UNION CIVIL' THEN
                    -- Unión Civil: dos primeras letras
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, 1, 2));
                WHEN 'DIVORCIADO' THEN
                    -- Divorciado: primera y última letra
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, 1, 1) || 
                                            SUBSTR(v_appaterno_emp, LENGTH(v_appaterno_emp), 1));
                WHEN 'SOLTERO' THEN
                    -- Soltero: primera y última letra
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, 1, 1) || 
                                            SUBSTR(v_appaterno_emp, LENGTH(v_appaterno_emp), 1));
                WHEN 'VIUDO' THEN
                    -- Viudo: antepenúltima y penúltima letra
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, LENGTH(v_appaterno_emp) - 2, 1) || 
                                            SUBSTR(v_appaterno_emp, LENGTH(v_appaterno_emp) - 1, 1));
                WHEN 'SEPARADO' THEN
                    -- Separado: dos últimas letras
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, LENGTH(v_appaterno_emp) - 1, 2));
                ELSE
                    -- Por defecto: dos primeras letras
                    v_dos_letras_ap := LOWER(SUBSTR(v_appaterno_emp, 1, 2));
            END CASE;
            
            -- 5. Mes y año actual (formato MMYYYY)
            v_mes_anio_actual := TO_CHAR(:b_fecha_proceso, 'MMYYYY');
            
            -- Construcción de la clave
            v_clave_usuario := v_tercer_digito_run || 
                              v_anio_nac_mas2 || 
                              v_ultimos_3_sueldo || 
                              v_dos_letras_ap || 
                              v_id_empleado || 
                              v_mes_anio_actual;
            
            -- Construcción del nombre completo
            v_nombre_completo := v_pnombre_emp || ' ' || v_appaterno_emp;
            
            -- ================================================================
            -- SENTENCIA SQL 2: INSERTAR REGISTRO EN TABLA USUARIO_CLAVE
            -- Almacena el usuario y clave generados en la tabla
            -- ================================================================
            INSERT INTO USUARIO_CLAVE (
                id_emp,
                numrun_emp,
                dvrun_emp,
                nombre_empleado,
                nombre_usuario,
                clave_usuario
            ) VALUES (
                v_id_empleado,
                v_numrun_emp,
                v_dvrun_emp,
                v_nombre_completo,
                v_nombre_usuario,
                v_clave_usuario
            );
            
            -- SENTENCIA PL/SQL 4: Incrementar contador de iteraciones
            -- Descripción: Suma 1 al contador por cada empleado procesado exitosamente
            -- Propósito: Validar que se procesaron todos los empleados antes de COMMIT
            v_contador := v_contador + 1;
            
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                -- Si no existe el empleado con ese ID, continuar con el siguiente
                NULL;
            WHEN OTHERS THEN
                -- Cualquier otro error se registra y se continúa
                DBMS_OUTPUT.PUT_LINE('Error procesando empleado ID ' || v_id_empleado || ': ' || SQLERRM);
        END;
        
    END LOOP;
    
    -- ========================================================================
    -- VALIDACIÓN Y CONFIRMACIÓN DE TRANSACCIONES
    -- Solo se hace COMMIT si se procesaron todos los empleados esperados
    -- ========================================================================
    IF v_contador = v_total_empleados THEN
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('PROCESO COMPLETADO EXITOSAMENTE');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Total de empleados procesados: ' || v_contador);
        DBMS_OUTPUT.PUT_LINE('Transacción confirmada (COMMIT)');
        DBMS_OUTPUT.PUT_LINE('');
    ELSE
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('ADVERTENCIA: PROCESO INCOMPLETO');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Empleados procesados: ' || v_contador);
        DBMS_OUTPUT.PUT_LINE('Empleados esperados: ' || v_total_empleados);
        DBMS_OUTPUT.PUT_LINE('Transacción revertida (ROLLBACK)');
        DBMS_OUTPUT.PUT_LINE('');
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('ERROR CRÍTICO EN EL PROCESO');
        DBMS_OUTPUT.PUT_LINE('=================================================');
        DBMS_OUTPUT.PUT_LINE('Código de error: ' || SQLCODE);
        DBMS_OUTPUT.PUT_LINE('Mensaje: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Transacción revertida (ROLLBACK)');
        DBMS_OUTPUT.PUT_LINE('');
END;
/

-- ============================================================================
-- CONSULTA DE VERIFICACIÓN
-- Muestra los primeros 10 registros generados ordenados por ID
-- ============================================================================

SELECT id_emp
FROM empleado
WHERE id_emp BETWEEN 100 AND 320
ORDER BY id_emp;

SELECT id_emp,
       numrun_emp || '-' || dvrun_emp AS run_empleado,
       nombre_empleado,
       nombre_usuario,
       clave_usuario
FROM USUARIO_CLAVE
ORDER BY id_emp
FETCH FIRST 20 ROWS ONLY;