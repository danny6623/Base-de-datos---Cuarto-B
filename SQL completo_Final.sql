-- =====================================================================
-- Sistema de Matriculacion Universitaria - Concurrencia y Consistencia
-- Motor: MySQL 8.x (InnoDB). Ejecutar en MySQL Workbench.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ESQUEMA
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS matriculacion;
CREATE DATABASE matriculacion CHARACTER SET utf8mb4;
USE matriculacion;

CREATE TABLE Estudiantes (
    estudiante_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    cedula        CHAR(10)     NOT NULL UNIQUE,
    facultad      VARCHAR(60)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Asignaturas (
    asignatura_id     INT AUTO_INCREMENT PRIMARY KEY,
    nombre_materia    VARCHAR(80) NOT NULL,
    docente           VARCHAR(80) NOT NULL,
    cupos_disponibles SMALLINT    NOT NULL,
    CONSTRAINT chk_cupos CHECK (cupos_disponibles >= 0)   -- evita cupos negativos
) ENGINE=InnoDB;

CREATE TABLE Registros_Matricula (
    registro_id    INT AUTO_INCREMENT PRIMARY KEY,
    estudiante_id  INT NOT NULL,
    asignatura_id  INT NOT NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado         ENUM('CONFIRMADA','PENDIENTE') NOT NULL DEFAULT 'PENDIENTE',
    CONSTRAINT fk_reg_est FOREIGN KEY (estudiante_id) REFERENCES Estudiantes(estudiante_id),
    CONSTRAINT fk_reg_asi FOREIGN KEY (asignatura_id) REFERENCES Asignaturas(asignatura_id),
    CONSTRAINT uq_est_asi UNIQUE (estudiante_id, asignatura_id)  -- no matricular 2 veces
) ENGINE=InnoDB

-- Datos de prueba
INSERT INTO Estudiantes (nombre, cedula, facultad) VALUES
 ('Ana Torres',  '0601234567', 'Ingenieria'),
 ('Luis Perez',  '0602345678', 'Ingenieria'),
 ('Maria Lopez', '0603456789', 'Ingenieria');

INSERT INTO Asignaturas (nombre_materia, docente, cupos_disponibles) VALUES
 ('Base de Datos',          'Dr. Salazar', 5),   -- id 1
 ('Programacion',           'Ing. Vega',   3),   -- id 2
 ('Redes',                  'Ing. Mora',   4),   -- id 3
 ('Sistemas Operativos',    'Ing. Cruz',   0),   -- id 4 (sin cupos)
 ('Ingenieria de Software', 'Dra. Ruiz',   5);   -- id 5 (para aislamiento)

SELECT * FROM Asignaturas;

-- ---------------------------------------------------------------------
-- 2. TRANSACCIONES ACID
-- ---------------------------------------------------------------------
SET autocommit = 1;

-- ===== Transaccion A: COMMIT =====
START TRANSACTION;
  INSERT INTO Registros_Matricula (estudiante_id, asignatura_id, estado)
  VALUES (1, 1, 'CONFIRMADA');
  UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1
  WHERE asignatura_id = 1;
COMMIT;
-- Verificacion (esperado: 1 registro; cupos Base de Datos = 4)
SELECT * FROM Registros_Matricula;
SELECT asignatura_id, nombre_materia, cupos_disponibles FROM Asignaturas WHERE asignatura_id = 1;

-- ===== Transaccion B: ROLLBACK =====
START TRANSACTION;
  INSERT INTO Registros_Matricula (estudiante_id, asignatura_id, estado)
  VALUES (2, 1, 'PENDIENTE');
  SELECT * FROM Registros_Matricula;   -- dentro de la transaccion: aparecen 2 filas
  -- Fallo simulado: el UPDATE de cupos nunca se ejecuta
ROLLBACK;
-- Verificacion (esperado: solo 1 fila, la del Estudiante 1; cupos siguen en 4)
SELECT * FROM Registros_Matricula;
SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 1;

-- ===== Transaccion C: Matricula multimateria =====
-- Estado inicial: Programacion = 3, Redes = 4, Sistemas Operativos = 0
START TRANSACTION;
  INSERT INTO Registros_Matricula (estudiante_id, asignatura_id, estado) VALUES (3, 2, 'CONFIRMADA');
  UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 2; -- exito
  INSERT INTO Registros_Matricula (estudiante_id, asignatura_id, estado) VALUES (3, 3, 'CONFIRMADA');
  UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 3; -- exito
  SELECT asignatura_id, cupos_disponibles FROM Asignaturas;   -- dentro: 2 -> 2, 3 -> 3
  -- Error forzado: materia 4 tiene 0 cupos, restar 1 viola chk_cupos (error 3819)
  UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 4;
-- (Al ocurrir el error, ejecutar manualmente:)
ROLLBACK;
-- Verificacion (esperado: Programacion = 3, Redes = 4; sin registros del Estudiante 3)
SELECT asignatura_id, nombre_materia, cupos_disponibles FROM Asignaturas;
SELECT * FROM Registros_Matricula WHERE estudiante_id = 3;

-- Nota: un UPDATE sobre un ID inexistente (ej. 999) en MySQL NO da error:
-- afecta 0 filas. Se detecta con ROW_COUNT() = 0.
START TRANSACTION;
  UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 999;
  SELECT ROW_COUNT() AS filas_afectadas;   -- 0 -> se debe hacer ROLLBACK
ROLLBACK;

-- ---------------------------------------------------------------------
-- 3. NIVELES DE AISLAMIENTO  (abrir DOS pestanas: SESION A y SESION B)
--    Ambas pestanas: USE matriculacion;
--    Antes de cada prueba (en cualquiera): reiniciar cupos
-- ---------------------------------------------------------------------
-- UPDATE Asignaturas SET cupos_disponibles = 5 WHERE asignatura_id = 5;

-- ===== 3.1 READ UNCOMMITTED (lectura sucia) =====
-- SESION A:
--   START TRANSACTION;
--   UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 5;
-- SESION B:
--   SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--   START TRANSACTION;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- ve 4 (dato sucio)
-- SESION A:
--   ROLLBACK;
-- SESION B:
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- ahora 5
--   COMMIT;

-- ===== 3.2 READ COMMITTED (lectura no repetible) =====
-- SESION B:
--   SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
--   START TRANSACTION;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- 5
-- SESION A:
--   START TRANSACTION;
--   UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 5;
-- SESION B:
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- sigue 5 (no ve sucio)
-- SESION A:
--   COMMIT;
-- SESION B:
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- ahora 4 (cambio a mitad)
--   COMMIT;

-- ===== 3.3 REPEATABLE READ =====
-- (reiniciar cupos a 5)
-- SESION B:
--   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
--   START TRANSACTION;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- 5
-- SESION A:
--   UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 5;  -- autocommit
-- SESION B:
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- sigue 5
--   COMMIT;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- ahora 4
-- Bloqueo de registros (reiniciar cupos a 5):
-- SESION B:
--   START TRANSACTION;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5 FOR SHARE;
-- SESION A:
--   UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 5;  -- QUEDA EN ESPERA
-- SESION B:
--   COMMIT;   -- A se libera y termina

-- ===== 3.4 SERIALIZABLE =====
-- (reiniciar cupos a 5)
-- SESION B:
--   SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
--   START TRANSACTION;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- 5 (toma bloqueo compartido)
-- SESION A:
--   START TRANSACTION;
--   UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1 WHERE asignatura_id = 5;  -- EN ESPERA
-- SESION B:
--   COMMIT;   -- A continua
-- SESION A:
--   COMMIT;
--   SELECT cupos_disponibles FROM Asignaturas WHERE asignatura_id = 5;  -- 4

-- Restaurar nivel por defecto:
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- ---------------------------------------------------------------------
-- 4. VALOR AGREGADO: procedimiento seguro de matricula
--    (FOR UPDATE evita sobreventa de cupos; ROLLBACK automatico ante error)
-- ---------------------------------------------------------------------
DELIMITER //
CREATE PROCEDURE sp_matricular(IN p_est INT, IN p_asi INT)
BEGIN
    DECLARE v_cupos INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: matricula revertida' AS resultado;
    END;

    START TRANSACTION;
      SELECT cupos_disponibles INTO v_cupos
      FROM Asignaturas WHERE asignatura_id = p_asi FOR UPDATE;   -- bloquea la fila

      IF v_cupos IS NULL OR v_cupos <= 0 THEN
          ROLLBACK;
          SELECT 'SIN CUPOS o materia inexistente' AS resultado;
      ELSE
          INSERT INTO Registros_Matricula (estudiante_id, asignatura_id, estado)
          VALUES (p_est, p_asi, 'CONFIRMADA');
          UPDATE Asignaturas SET cupos_disponibles = cupos_disponibles - 1
          WHERE asignatura_id = p_asi;
          COMMIT;
          SELECT 'MATRICULA CONFIRMADA' AS resultado;
      END IF;
END //
DELIMITER ;

-- Pruebas:
CALL sp_matricular(2, 5);   -- exito
CALL sp_matricular(2, 4);   -- sin cupos
CALL sp_matricular(2, 5);   -- duplicado -> error -> rollback