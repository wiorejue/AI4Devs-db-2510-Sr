# Plan de Migración de Base de Datos - ATS System

Este documento detalla el flujo de trabajo para migrar la base de datos del sistema legado a la nueva arquitectura optimizada y normalizada.

```mermaid
graph TD
    %% Estilos
    classDef critical fill:#f96,stroke:#333,stroke-width:2px;
    classDef process fill:#9cf,stroke:#333,stroke-width:1px;
    classDef db fill:#bfb,stroke:#333,stroke-width:1px;

    Start((Inicio)) --> Backup[🔒 Backup Completo de BD]
    class Backup critical

    Backup --> Rename[🔄 Renombrar Tablas Existentes<br/>Prefix: legacy_*]
    class Rename process

    Rename --> NewSchema[🏗️ Desplegar Nuevo Esquema<br/>(script.sql / Prisma)]
    class NewSchema db

    NewSchema --> MigrationScripts{🚀 Ejecutar Scripts de ETL}
    class MigrationScripts process

    subgraph ETL_Process [Transformación y Carga de Datos]
        direction TB
        Step1[🏢 Migrar Compañías]
        Step2[📚 Migrar Catálogos<br/>(Interview Flows & Types)]
        Step3[👥 Migrar Empleados<br/>MAP: Roles Strings -> ENUMs]
        Step4[👤 Migrar Candidatos]
        Step5[📋 Migrar Posiciones<br/>MAP: Status/Type -> ENUMs]
        Step6[📄 Migrar Aplicaciones<br/>MAP: Status -> ENUMs]
        Step7[🤝 Migrar Entrevistas<br/>MAP: Result -> ENUMs]
        Step8[🎓 Migrar Detalles<br/>(Experiencia/Educación)]

        MigrationScripts --> Step1
        Step1 --> Step2
        Step2 --> Step3
        Step3 --> Step4
        Step4 --> Step5
        Step5 --> Step6
        Step6 --> Step7
        Step7 --> Step8
    end

    Step8 --> ResetSeq[🔢 Resetear Secuencias <br/>(SERIAL ID Sync)]
    
    ResetSeq --> Validation{✅ Validación de Datos}
    class Validation critical

    Validation -- Error --> Rollback[⏪ Rollback a Backup]
    Validation -- OK --> Cleanup[🧹 Limpieza de Tablas Legacy<br/>(Opcional)]
    
    Cleanup --> End((Fin de Migración))
```

## Detalles del Proceso

1.  **Backup**: Snapshot completo de la base de datos `LTIdb` antes de cualquier operación.
2.  **Renombrado**: `ALTER TABLE x RENAME TO legacy_x`. Esto libera los nombres de tabla para el nuevo esquema limpio.
3.  **Nuevo Esquema (DDL)**: Ejecución de `script.sql` para crear tablas con integridad referencial, Enums y Auditoría.
4.  **ETL (Migración)**: Ejecución de `migracion.sql`.
    *   Las transformaciones ocurren "al vuelo" usando `INSERT INTO ... SELECT ... CASE ...`.
    *   Se preservan los IDs originales para mantener relaciones.
5.  **Validación**:
    *   Verificar `COUNT(*)` entre `legacy_table` y `new_table`.
    *   Verificar integridad de datos en campos ENUM convertidos.
