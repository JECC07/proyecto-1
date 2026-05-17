-- =========================================
-- SCRIPT ABASTECIMIENTO - BDFarmacia
-- SQL Server 2022
-- Tablas nuevas: PROVEEDOR, CONTACTO_PROVEEDOR,
--                ORDEN_COMPRA, DETALLE_ORDEN_COMPRA,
--                RECEPCION_COMPRA, DETALLE_RECEPCION
-- =========================================

USE BDFarmacia
GO

-- =============================
-- ELIMINAR SI EXISTEN (orden inverso de dependencias)
-- =============================

IF OBJECT_ID('DETALLE_RECEPCION',    'U') IS NOT NULL DROP TABLE DETALLE_RECEPCION
IF OBJECT_ID('RECEPCION_COMPRA',     'U') IS NOT NULL DROP TABLE RECEPCION_COMPRA
IF OBJECT_ID('DETALLE_ORDEN_COMPRA', 'U') IS NOT NULL DROP TABLE DETALLE_ORDEN_COMPRA
IF OBJECT_ID('ORDEN_COMPRA',         'U') IS NOT NULL DROP TABLE ORDEN_COMPRA
IF OBJECT_ID('CONTACTO_PROVEEDOR',   'U') IS NOT NULL DROP TABLE CONTACTO_PROVEEDOR
IF OBJECT_ID('PROVEEDOR',            'U') IS NOT NULL DROP TABLE PROVEEDOR
GO

-- =============================
-- TABLA PROVEEDOR
-- Empresa o persona que suministra productos a la farmacia.
-- RUC obligatorio (11 digitos) porque en Peru los proveedores
-- son personas juridicas o naturales con negocio.
-- =============================

CREATE TABLE PROVEEDOR (
    IDPROVEEDOR     INT           IDENTITY(1,1) NOT NULL,
    RUC             CHAR(11)      NOT NULL,
    RAZONSOCIAL     VARCHAR(150)  NOT NULL,
    NOMBRECOMERCIAL VARCHAR(150),
    DIRECCION       VARCHAR(200),
    TELEFONO        CHAR(9),
    CORREO          VARCHAR(100),
    PAGINAWEB       VARCHAR(100),
    CONDICIONPAGO   VARCHAR(50),   -- 'Contado', 'Credito 30 dias', etc.
    ESTADO          BIT           NOT NULL DEFAULT 1,
    FECHAREGISTRO   DATE          NOT NULL DEFAULT GETDATE(),

    CONSTRAINT PK_PROVEEDOR  PRIMARY KEY (IDPROVEEDOR),
    CONSTRAINT UQ_PROVEEDOR_RUC         UNIQUE (RUC),
    CONSTRAINT CK_PROVEEDOR_RUC         CHECK  (LEN(RUC) = 11),
    CONSTRAINT CK_PROVEEDOR_CONDICION   CHECK  (
        CONDICIONPAGO IN ('Contado','Credito 15 dias','Credito 30 dias',
                          'Credito 45 dias','Credito 60 dias') OR
        CONDICIONPAGO IS NULL
    )
)
GO

-- =============================
-- TABLA CONTACTO_PROVEEDOR
-- Un proveedor puede tener varios contactos (vendedor,
-- administrador, logistica). Se separa para normalizar.
-- =============================

CREATE TABLE CONTACTO_PROVEEDOR (
    IDCONTACTO      INT           IDENTITY(1,1) NOT NULL,
    IDPROVEEDOR     INT           NOT NULL,
    NOMBRES         VARCHAR(100)  NOT NULL,
    CARGO           VARCHAR(80),
    TELEFONO        CHAR(9),
    CELULAR         CHAR(9),
    CORREO          VARCHAR(100),
    PRINCIPAL       BIT           NOT NULL DEFAULT 0,  -- 1 = contacto principal

    CONSTRAINT PK_CONTACTO_PROVEEDOR PRIMARY KEY (IDCONTACTO),
    CONSTRAINT FK_CONTACTO_PROVEEDOR
        FOREIGN KEY (IDPROVEEDOR) REFERENCES PROVEEDOR(IDPROVEEDOR)
)
GO

-- =============================
-- TABLA ORDEN_COMPRA
-- Documento formal que la farmacia emite al proveedor
-- solicitando productos. Puede quedar pendiente, aprobada,
-- recibida parcialmente o anulada.
-- =============================

CREATE TABLE ORDEN_COMPRA (
    IDORDEN         INT           IDENTITY(1,1) NOT NULL,
    NROORDEN        VARCHAR(20)   NOT NULL,          -- Ej: OC-2026-001
    FECHAEMISION    DATE          NOT NULL DEFAULT GETDATE(),
    FECHAESPERADA   DATE,                            -- Fecha esperada de llegada
    ESTADO          VARCHAR(20)   NOT NULL DEFAULT 'Pendiente',
    OBSERVACION     VARCHAR(300),
    SUBTOTAL        DECIMAL(12,2) NOT NULL DEFAULT 0,
    IGV             DECIMAL(12,2) NOT NULL DEFAULT 0,
    TOTAL           DECIMAL(12,2) NOT NULL DEFAULT 0,
    IDPROVEEDOR     INT           NOT NULL,
    IDUSUARIO       INT           NOT NULL,          -- Quien genero la orden

    CONSTRAINT PK_ORDEN_COMPRA   PRIMARY KEY (IDORDEN),
    CONSTRAINT UQ_ORDEN_NROORDEN UNIQUE      (NROORDEN),
    CONSTRAINT FK_ORDEN_PROVEEDOR
        FOREIGN KEY (IDPROVEEDOR) REFERENCES PROVEEDOR(IDPROVEEDOR),
    CONSTRAINT FK_ORDEN_USUARIO
        FOREIGN KEY (IDUSUARIO)   REFERENCES USUARIO(IDUSUARIO),
    CONSTRAINT CK_ORDEN_ESTADO   CHECK (
        ESTADO IN ('Pendiente','Aprobada','Recibida','Recibida parcial','Anulada')
    ),
    CONSTRAINT CK_ORDEN_FECHAS   CHECK (
        FECHAESPERADA IS NULL OR FECHAESPERADA >= FECHAEMISION
    )
)
GO

-- =============================
-- TABLA DETALLE_ORDEN_COMPRA
-- Cada linea de la orden: que producto, cuantas unidades
-- y a que precio pactado con el proveedor.
-- Referencia DETALLE_PRODUCTO porque se compra una
-- presentacion especifica de un producto de una marca.
-- =============================

CREATE TABLE DETALLE_ORDEN_COMPRA (
    IDDETALLEORDEN      INT           IDENTITY(1,1) NOT NULL,
    IDORDEN             INT           NOT NULL,
    IDDETALLEPRODUCTO   INT           NOT NULL,
    CANTIDADPEDIDA      INT           NOT NULL,
    CANTIDADRECIBIDA    INT           NOT NULL DEFAULT 0,
    PRECIOUNITARIO      DECIMAL(10,2) NOT NULL,
    SUBTOTAL            AS (CANTIDADPEDIDA * PRECIOUNITARIO),  -- columna calculada

    CONSTRAINT PK_DETALLE_ORDEN      PRIMARY KEY (IDDETALLEORDEN),
    CONSTRAINT FK_DORDEN_ORDEN
        FOREIGN KEY (IDORDEN)           REFERENCES ORDEN_COMPRA(IDORDEN),
    CONSTRAINT FK_DORDEN_DETPRODUCTO
        FOREIGN KEY (IDDETALLEPRODUCTO) REFERENCES DETALLE_PRODUCTO(IDDETALLEPRODUCTO),
    CONSTRAINT UQ_DORDEN_PRODUCTO
        UNIQUE (IDORDEN, IDDETALLEPRODUCTO),
    CONSTRAINT CK_DORDEN_CANTIDAD
        CHECK (CANTIDADPEDIDA > 0),
    CONSTRAINT CK_DORDEN_PRECIO
        CHECK (PRECIOUNITARIO > 0),
    CONSTRAINT CK_DORDEN_RECIBIDA
        CHECK (CANTIDADRECIBIDA >= 0 AND CANTIDADRECIBIDA <= CANTIDADPEDIDA)
)
GO

-- =============================
-- TABLA RECEPCION_COMPRA
-- Registro fisico de cuando llega la mercaderia.
-- Una orden puede tener varias recepciones (entregas parciales).
-- Quien recibe queda registrado (IDUSUARIO = almacenero).
-- =============================

CREATE TABLE RECEPCION_COMPRA (
    IDRECEPCION     INT           IDENTITY(1,1) NOT NULL,
    IDORDEN         INT           NOT NULL,
    NRORECEPCION    VARCHAR(20)   NOT NULL,          -- Ej: REC-2026-001
    FECHARECEPCION  DATETIME      NOT NULL DEFAULT GETDATE(),
    NROFACTURA      VARCHAR(30),                     -- Factura del proveedor
    OBSERVACION     VARCHAR(300),
    ESTADO          VARCHAR(20)   NOT NULL DEFAULT 'Completa',
    IDUSUARIO       INT           NOT NULL,          -- Almacenero que recibe

    CONSTRAINT PK_RECEPCION      PRIMARY KEY (IDRECEPCION),
    CONSTRAINT UQ_RECEPCION_NRO  UNIQUE      (NRORECEPCION),
    CONSTRAINT FK_RECEPCION_ORDEN
        FOREIGN KEY (IDORDEN)    REFERENCES ORDEN_COMPRA(IDORDEN),
    CONSTRAINT FK_RECEPCION_USUARIO
        FOREIGN KEY (IDUSUARIO)  REFERENCES USUARIO(IDUSUARIO),
    CONSTRAINT CK_RECEPCION_ESTADO CHECK (
        ESTADO IN ('Completa','Parcial','Con observacion')
    )
)
GO

-- =============================
-- TABLA DETALLE_RECEPCION
-- Cada linea de la recepcion: producto recibido,
-- cantidad real y datos del lote (vencimiento, fabricacion).
-- Al registrar esto, el sistema debe actualizar LOTE
-- o crear uno nuevo si es lote diferente.
-- =============================

CREATE TABLE DETALLE_RECEPCION (
    IDDETRECEPCION      INT           IDENTITY(1,1) NOT NULL,
    IDRECEPCION         INT           NOT NULL,
    IDDETALLEORDEN      INT           NOT NULL,      -- Linea de la OC correspondiente
    CANTIDADRECIBIDA    INT           NOT NULL,
    PRECIOCOMPRA        DECIMAL(10,2) NOT NULL,      -- Precio real (puede diferir del pactado)
    NROLOTE             VARCHAR(50)   NOT NULL,
    FECHAVENCIMIENTO    DATE          NOT NULL,
    FECHAFABRICACION    DATE,
    IDLOTE              INT,                         -- FK a LOTE una vez registrado

    CONSTRAINT PK_DETALLE_RECEPCION  PRIMARY KEY (IDDETRECEPCION),
    CONSTRAINT FK_DETREC_RECEPCION
        FOREIGN KEY (IDRECEPCION)    REFERENCES RECEPCION_COMPRA(IDRECEPCION),
    CONSTRAINT FK_DETREC_DETORDEN
        FOREIGN KEY (IDDETALLEORDEN) REFERENCES DETALLE_ORDEN_COMPRA(IDDETALLEORDEN),
    CONSTRAINT FK_DETREC_LOTE
        FOREIGN KEY (IDLOTE)         REFERENCES LOTE(IDLOTE),
    CONSTRAINT CK_DETREC_CANTIDAD
        CHECK (CANTIDADRECIBIDA > 0),
    CONSTRAINT CK_DETREC_PRECIO
        CHECK (PRECIOCOMPRA > 0),
    CONSTRAINT CK_DETREC_VENCIMIENTO
        CHECK (FECHAVENCIMIENTO > GETDATE()),
    CONSTRAINT CK_DETREC_FABRICACION
        CHECK (FECHAFABRICACION IS NULL OR FECHAFABRICACION <= GETDATE())
)
GO

-- =============================
-- DATOS DE PRUEBA
-- =============================

INSERT INTO PROVEEDOR (RUC, RAZONSOCIAL, NOMBRECOMERCIAL, DIRECCION, TELEFONO,
                       CORREO, CONDICIONPAGO, ESTADO)
VALUES
('20100055888', 'LABORATORIOS PORTUGAL S.A.C.',    'Lab Portugal',
 'Av. Industrial 456, Lima', '014512233', 'ventas@labportugal.com.pe',
 'Credito 30 dias', 1),

('20512345678', 'DROGUERIA MEDIFARMA S.A.',         'Medifarma',
 'Jr. Comercio 789, Lima',  '014523344', 'pedidos@medifarma.pe',
 'Contado', 1),

('20609876543', 'DISTRIBUIDORA INKA PHARMA E.I.R.L.','Inka Pharma',
 'Calle Los Pinos 102, Chiclayo', '074201122', 'inkapharmachl@gmail.com',
 'Credito 15 dias', 1)
GO

INSERT INTO CONTACTO_PROVEEDOR (IDPROVEEDOR, NOMBRES, CARGO, CELULAR, CORREO, PRINCIPAL)
VALUES
(1, 'Roberto Llontop',  'Representante de ventas', '987001122', 'rllontop@labportugal.com.pe',   1),
(1, 'Carmen Davila',    'Logistica',               '987003344', 'cdavila@labportugal.com.pe',    0),
(2, 'Jorge Huaman',     'Ejecutivo de cuenta',     '987005566', 'jhuaman@medifarma.pe',          1),
(3, 'Lucia Farro',      'Administradora',          '987007788', 'lfarro@inkapharmachl@gmail.com', 1)
GO

INSERT INTO ORDEN_COMPRA (NROORDEN, FECHAEMISION, FECHAESPERADA, ESTADO,
                          OBSERVACION, IDPROVEEDOR, IDUSUARIO)
VALUES
('OC-2026-001', '2026-05-01', '2026-05-10', 'Recibida',
 'Primera orden del mes de mayo', 1, 5),

('OC-2026-002', '2026-05-10', '2026-05-20', 'Pendiente',
 'Reposicion de antibioticos', 2, 5),

('OC-2026-003', '2026-05-15', '2026-05-25', 'Aprobada',
 'Productos de alta rotacion', 3, 5)
GO

-- =============================
-- VISTAS UTILES
-- =============================

-- Vista: estado actual de ordenes de compra con proveedor
CREATE OR ALTER VIEW VW_ORDENES_COMPRA AS
SELECT
    OC.IDORDEN,
    OC.NROORDEN,
    OC.FECHAEMISION,
    OC.FECHAESPERADA,
    OC.ESTADO,
    P.RAZONSOCIAL        AS PROVEEDOR,
    P.CONDICIONPAGO,
    U.NOMBRE + ' ' + U.APELLIDOPATERNO AS GENERADOPOR,
    OC.TOTAL,
    OC.OBSERVACION
FROM ORDEN_COMPRA OC
INNER JOIN PROVEEDOR P ON OC.IDPROVEEDOR = P.IDPROVEEDOR
INNER JOIN USUARIO   U ON OC.IDUSUARIO   = U.IDUSUARIO
GO

-- Vista: detalle de ordenes con producto y cantidad pendiente de recibir
CREATE OR ALTER VIEW VW_DETALLE_ORDENES AS
SELECT
    OC.NROORDEN,
    OC.ESTADO                                       AS ESTADO_ORDEN,
    P.NOMBRE                                        AS PRODUCTO,
    M.NOMBREMARCA                                   AS MARCA,
    PR2.TIPOPRESENTACION + ' x ' + 
        CAST(PR2.CANTIDAD AS VARCHAR) + ' ' + 
        PR2.UNIDAD                                  AS PRESENTACION,
    DOC.CANTIDADPEDIDA,
    DOC.CANTIDADRECIBIDA,
    DOC.CANTIDADPEDIDA - DOC.CANTIDADRECIBIDA       AS PENDIENTE,
    DOC.PRECIOUNITARIO,
    DOC.SUBTOTAL
FROM DETALLE_ORDEN_COMPRA DOC
INNER JOIN ORDEN_COMPRA    OC  ON DOC.IDORDEN           = OC.IDORDEN
INNER JOIN DETALLE_PRODUCTO DP ON DOC.IDDETALLEPRODUCTO = DP.IDDETALLEPRODUCTO
INNER JOIN PRODUCTO          P  ON DP.IDPRODUCTO         = P.IDPRODUCTO
INNER JOIN MARCA             M  ON DP.IDMARCA            = M.IDMARCA
INNER JOIN PRESENTACION      PR2 ON DP.IDPRESENTACION   = PR2.IDPRESENTACION
GO

-- Vista: proveedores activos con contacto principal
CREATE OR ALTER VIEW VW_PROVEEDORES AS
SELECT
    P.IDPROVEEDOR,
    P.RUC,
    P.RAZONSOCIAL,
    P.NOMBRECOMERCIAL,
    P.CONDICIONPAGO,
    P.TELEFONO                  AS TEL_EMPRESA,
    CP.NOMBRES                  AS CONTACTO_PRINCIPAL,
    CP.CARGO,
    CP.CELULAR                  AS CEL_CONTACTO,
    CP.CORREO                   AS CORREO_CONTACTO
FROM PROVEEDOR P
LEFT JOIN CONTACTO_PROVEEDOR CP
       ON P.IDPROVEEDOR = CP.IDPROVEEDOR AND CP.PRINCIPAL = 1
WHERE P.ESTADO = 1
GO

PRINT 'Script Abastecimiento ejecutado correctamente.'
GO
