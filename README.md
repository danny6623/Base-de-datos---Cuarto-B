# Base-de-datos---Cuarto-B
# Sistema de Matriculación Universitaria: Concurrencia y Consistencia

**Asignatura:** Administración de Bases de Datos
**Unidad 1:** Programación avanzada en SQL – Transacciones
**Tema 1:** Introducción a la Administración de Bases de Datos y Transacciones
**Universidad Nacional de Chimborazo – Facultad de Ingeniería**

**Autor:** Danny Basantes
**Carrera / Semestre:** Ciencia de datos e IA... CUARTO B

---

## Descripción

Base de datos que gestiona la disponibilidad de cupos en las asignaturas de una universidad. El proyecto demuestra, con MySQL, cómo se mantiene la integridad de los datos mediante:

- Transacciones con propiedades **ACID** (`COMMIT`, `ROLLBACK`, atomicidad en matrícula multimateria).
- **Control de bloqueos** y los 4 **niveles de aislamiento** (Read Uncommitted, Read Committed, Repeatable Read, Serializable) usando dos sesiones simultáneas.
- Un procedimiento almacenado (`sp_matricular`) que evita la sobreventa de cupos.

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `Apellido_Nombre_Unidad1_Tema1.sql` | Script completo: esquema, datos de prueba, transacciones, guion de aislamiento y procedimiento |
| `Apellido_Nombre_Unidad1_Tema1.pdf` | Informe con el desarrollo paso a paso y el análisis técnico |
| `Apellido_Nombre_Unidad1_Tema1.tex` | Código fuente LaTeX del informe |
| `capturas/` | Evidencias (capturas de pantalla) usadas en el informe |

## Modelo de datos

- **Estudiantes**(`estudiante_id` PK, `nombre`, `cedula`, `facultad`)
- **Asignaturas**(`asignatura_id` PK, `nombre_materia`, `docente`, `cupos_disponibles`) con `CHECK (cupos_disponibles >= 0)`
- **Registros_Matricula**(`registro_id` PK, `estudiante_id` FK, `asignatura_id` FK, `fecha_registro`, `estado` ∈ {CONFIRMADA, PENDIENTE})

## Requisitos

- MySQL Server 8.x (motor InnoDB)
- MySQL Workbench 8.x (o cliente de línea de comandos)

## Cómo ejecutarlo

1. Abre `Apellido_Nombre_Unidad1_Tema1.sql` en MySQL Workbench (*File → Open SQL Script*).
2. Ejecuta las secciones **1 (Esquema)** y **2 (Transacciones)** **por bloques**: selecciona las líneas de cada transacción y presiona `Ctrl+Enter`.
   - En la Transacción C el error `3819` es intencional; después de verlo, ejecuta `ROLLBACK;`.
3. Para la sección **3 (Aislamiento)**:
   - Abre **dos pestañas** de consulta (Sesión A y Sesión B) y ejecuta `USE matriculacion;` en ambas.
   - Antes de cada prueba reinicia los cupos:
     ```sql
     UPDATE Asignaturas SET cupos_disponibles = 5 WHERE asignatura_id = 5;
     ```
   - Copia y ejecuta los pasos comentados del script, alternando entre A y B en el orden indicado.
4. Ejecuta la sección **4** para crear y probar `sp_matricular`.

## Resultados esperados

| Prueba | Resultado |
|---|---|
| Transacción A (COMMIT) | Registro creado y cupo de Base de Datos baja de 5 a 4 |
| Transacción B (ROLLBACK) | La tabla de registros queda sin el INSERT; cupo sin cambios |
| Transacción C (multimateria) | Error 3819 en la 3.ª materia; todo se revierte (atomicidad) |
| Read Uncommitted | B lee 4 (lectura sucia) y luego 5 |
| Read Committed | B lee 5 y luego 4 (lectura no repetible) |
| Repeatable Read | B lee siempre 5; con `FOR SHARE` el UPDATE de A espera |
| Serializable | El UPDATE de A queda en espera hasta el COMMIT de B |

## Notas

- En MySQL un `UPDATE` sobre un ID inexistente no genera error (afecta 0 filas); se detecta con `ROW_COUNT()`.
- Las lecturas simples en Repeatable Read usan MVCC y no bloquean; el bloqueo se obtiene con `FOR SHARE` / `FOR UPDATE`.

## Referencias

- Silberschatz, A., Korth, H. F., & Sudarshan, S. (2020). *Database system concepts* (5th ed.). McGraw-Hill.
- Elmasri, R., & Navathe, S. (2021). *Fundamentals of database systems* (7th ed.). Pearson.
