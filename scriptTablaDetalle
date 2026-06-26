-- =============================================================================
-- CREACIÓN DE TABLA DE HECHOS: DETALLE (Últimos 4 meses)
-- =============================================================================
DROP TABLE IF EXISTS t_padron_sunat_detalle;

CREATE TABLE t_padron_sunat_detalle (
    ruc         VARCHAR(11) NOT NULL,
    sk_ubigeo   INT NOT NULL,
    sk_tiempo   INT NOT NULL,
    sk_estado   INT NOT NULL,
    sk_perfil   INT NOT NULL,
    sk_ciiu     INT NOT NULL,
    nro_trab    VARCHAR(50) -- Lo mantenemos como viene (texto) por la imputación 'NO DISPONIBLE'
);

-- =============================================================================
-- LLENADO DE LA TABLA DETALLE
-- Cruzamos datos_limpios con las dimensiones, filtrando dinámicamente
-- =============================================================================
INSERT INTO t_padron_sunat_detalle (
    ruc, sk_ubigeo, sk_tiempo, sk_estado, sk_perfil, sk_ciiu, nro_trab
)
SELECT 
    d.ruc,
    du.sk_ubigeo,
    dt.sk_tiempo,
    de.sk_estado,
    dp.sk_perfil,
    dc.sk_ciiu,
    d.nro_trab
FROM datos_limpios d

-- Cruzamos con cada dimensión para obtener su respectivo ID (Surrogate Key)
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

-- La magia: Filtramos SOLO los registros que pertenezcan a los 4 periodos más recientes
WHERE d.periodo_publicacion IN (
    SELECT periodo 
    FROM t_dim_tiempo 
    WHERE periodo <> '000000' 
    ORDER BY periodo DESC 
    LIMIT 4
);

-- Creamos índices básicos para que el dashboard vuele al filtrar
CREATE INDEX idx_detalle_ruc ON t_padron_sunat_detalle(ruc);
CREATE INDEX idx_detalle_tiempo ON t_padron_sunat_detalle(sk_tiempo);
CREATE INDEX idx_detalle_ubigeo ON t_padron_sunat_detalle(sk_ubigeo);
