-- =============================================================================
-- CREACIÓN DE DIMENSIONES (MODELO ESTRELLA)
-- Se extraen los valores únicos (DISTINCT) de la tabla datos_limpios
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. DIMENSIÓN: UBIGEO (T_DIM_UBIGEO)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_dim_ubigeo CASCADE;

CREATE TABLE t_dim_ubigeo (
    sk_ubigeo    SERIAL PRIMARY KEY,
    codigo_inei  VARCHAR(6) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    provincia    VARCHAR(100) NOT NULL,
    distrito     VARCHAR(100) NOT NULL
);

INSERT INTO t_dim_ubigeo (codigo_inei, departamento, provincia, distrito)
SELECT DISTINCT 
    ubigeo, 
    departamento, 
    provincia, 
    distrito
FROM datos_limpios
ORDER BY departamento, provincia, distrito;

-- -----------------------------------------------------------------------------
-- 2. DIMENSIÓN: TIEMPO (T_DIM_TIEMPO)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_dim_tiempo CASCADE;

CREATE TABLE t_dim_tiempo (
    sk_tiempo SERIAL PRIMARY KEY,
    periodo   VARCHAR(6) NOT NULL,
    anio      INT NOT NULL,
    mes       INT NOT NULL
);

-- Extraemos el año y el mes del texto (Ej: '202312' -> Año 2023, Mes 12)
INSERT INTO t_dim_tiempo (periodo, anio, mes)
SELECT DISTINCT 
    periodo_publicacion,
    CAST(SUBSTRING(periodo_publicacion FROM 1 FOR 4) AS INT) AS anio,
    CAST(SUBSTRING(periodo_publicacion FROM 5 FOR 2) AS INT) AS mes
FROM datos_limpios
WHERE periodo_publicacion <> '000000'
ORDER BY periodo_publicacion;

-- Agregamos el registro por defecto para los periodos no identificados
INSERT INTO t_dim_tiempo (periodo, anio, mes) 
VALUES ('000000', 0, 0);

-- -----------------------------------------------------------------------------
-- 3. DIMENSIÓN: ESTADO Y CONDICIÓN (T_DIM_ESTADO)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_dim_estado CASCADE;

CREATE TABLE t_dim_estado (
    sk_estado SERIAL PRIMARY KEY,
    estado    VARCHAR(60) NOT NULL,
    condicion VARCHAR(60) NOT NULL,
    tipo      VARCHAR(300) NOT NULL
);

INSERT INTO t_dim_estado (estado, condicion, tipo)
SELECT DISTINCT 
    estado, 
    condicion, 
    tipo
FROM datos_limpios
ORDER BY estado, condicion;

-- -----------------------------------------------------------------------------
-- 4. DIMENSIÓN: PERFIL COMERCIAL (T_DIM_PERFIL_COMERCIAL)
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_dim_perfil_comercial CASCADE;

CREATE TABLE t_dim_perfil_comercial (
    sk_perfil         SERIAL PRIMARY KEY,
    tipo_facturacion  VARCHAR(200) NOT NULL,
    tipo_contabilidad VARCHAR(200) NOT NULL,
    comercio_exterior VARCHAR(200) NOT NULL
);

INSERT INTO t_dim_perfil_comercial (tipo_facturacion, tipo_contabilidad, comercio_exterior)
SELECT DISTINCT 
    tipo_facturacion, 
    tipo_contabilidad, 
    comercio_exterior
FROM datos_limpios
ORDER BY comercio_exterior, tipo_facturacion;

-- -----------------------------------------------------------------------------
-- 5. DIMENSIÓN: CIIU (Actividad Económica) - *Mejora sugerida*
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS t_dim_ciiu CASCADE;

CREATE TABLE t_dim_ciiu (
    sk_ciiu             SERIAL PRIMARY KEY,
    ciiu_v3_principal   VARCHAR(400) NOT NULL,
    ciiu_v4_principal   VARCHAR(400) NOT NULL
);

INSERT INTO t_dim_ciiu (ciiu_v3_principal, ciiu_v4_principal)
SELECT DISTINCT 
    ciiu_v3_principal, 
    ciiu_v4_principal
FROM datos_limpios
ORDER BY ciiu_v4_principal;
