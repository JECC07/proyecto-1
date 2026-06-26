-- =============================================================================
-- CREACIÓN DE TABLA DE HECHOS: RESUMEN HISTÓRICO (Toda la historia)
-- =============================================================================
DROP TABLE IF EXISTS t_padron_sunat_resumen;

CREATE TABLE t_padron_sunat_resumen (
    sk_ubigeo          INT NOT NULL,
    sk_tiempo          INT NOT NULL,
    sk_estado          INT NOT NULL,
    sk_perfil          INT NOT NULL,
    sk_ciiu            INT NOT NULL,
    
    -- Métricas (Medidas / Hechos)
    cantidad_empresas  INT NOT NULL,
    total_trabajadores INT NOT NULL
);

-- =============================================================================
-- LLENADO DE LA TABLA RESUMEN
-- Agrupamos TODA la historia, eliminando el RUC para comprimir los datos
-- =============================================================================
INSERT INTO t_padron_sunat_resumen (
    sk_ubigeo, sk_tiempo, sk_estado, sk_perfil, sk_ciiu, 
    cantidad_empresas, total_trabajadores
)
SELECT 
    du.sk_ubigeo,
    dt.sk_tiempo,
    de.sk_estado,
    dp.sk_perfil,
    dc.sk_ciiu,
    
    -- Métrica 1: Conteo de empresas únicas en ese cruce
    COUNT(d.ruc) AS cantidad_empresas,
    
    -- Métrica 2: Suma segura de trabajadores (Convirtiendo texto a número)
    SUM(
        CASE 
            WHEN d.nro_trab = 'NO DISPONIBLE' THEN 0 
            ELSE CAST(d.nro_trab AS INTEGER) 
        END
    ) AS total_trabajadores

FROM datos_limpios d

-- Los mismos JOINs para obtener los IDs
JOIN t_dim_ubigeo du 
  ON d.ubigeo = du.codigo_inei
JOIN t_dim_tiempo dt 
  ON d.periodo_publicacion = dt.periodo
JOIN t_dim_estado de 
  ON d.estado = de.estado 
 AND d.condicion = de.condicion 
 AND d.tipo = de.tipo
JOIN t_dim_perfil_comercial dp 
  ON d.tipo_facturacion = dp.tipo_facturacion 
 AND d.tipo_contabilidad = dp.tipo_contabilidad 
 AND d.comercio_exterior = dp.comercio_exterior
JOIN t_dim_ciiu dc 
  ON d.ciiu_v3_principal = dc.ciiu_v3_principal 
 AND d.ciiu_v4_principal = dc.ciiu_v4_principal

-- La magia de la compresión: Agrupamos por todas las dimensiones
GROUP BY 
    du.sk_ubigeo,
    dt.sk_tiempo,
    de.sk_estado,
    dp.sk_perfil,
    dc.sk_ciiu;

-- Creamos índices para que los reportes históricos carguen al instante
CREATE INDEX idx_resumen_tiempo ON t_padron_sunat_resumen(sk_tiempo);
CREATE INDEX idx_resumen_ubigeo ON t_padron_sunat_resumen(sk_ubigeo);
