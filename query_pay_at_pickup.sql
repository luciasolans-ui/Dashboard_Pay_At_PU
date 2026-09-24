-- ==============================================================================
-- QUERY OFICIAL PAY AT PICKUP: AGREGACIÓN DE SPLIT ORDERS, CONTACT RATE (COD) & KEY METRICS
-- Proyecto: peya-argentina
-- Tabla Base: `peya-argentina.automated_tables_reports.pay_at_pu` (actualizada diariamente a las 10:55 AM)
-- Cruces:
--   - `peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance` (is_split, deliveries_netos)
--   - `peya-data-origins-pro.cl_gcc_service.pandacare_chats` (Contact Rate Rider - COD issue / falta de efectivo)
-- ==============================================================================

DECLARE dInf DATE;
DECLARE dSup DATE;
SET dInf = '2026-08-19'; -- Período completo (Baseline 28d + Test)
SET dSup = CURRENT_DATE(); -- Fecha actual

WITH RiderChatsCOD AS (
  SELECT
    order_id,
    COUNT(DISTINCT chat_id) AS total_cod_chats
  FROM `peya-data-origins-pro.cl_gcc_service.pandacare_chats`
  WHERE created_date BETWEEN dInf - 1 AND dSup + 1
    AND created_date_localtime >= dInf
    AND created_date_localtime <= dSup
    AND global_entity_id = 'PY_AR'
    AND stakeholder = 'Rider'
    AND contact_reason_l3 = 'COD issue'
  GROUP BY 1
),

RawOrders AS (
  SELECT
    p.date,
    CASE 
      WHEN LOWER(TRIM(p.city_name)) IN ('rafaela', 'san salvador de jujuy', 'jujuy') THEN 'Jujuy + Rafaela'
      ELSE 'Otras ciudades'
    END AS city_group,
    p.city_name,
    CASE 
      WHEN LOWER(TRIM(p.vertical)) = 'restaurant' OR LOWER(TRIM(p.vertical_type)) LIKE '%restaurant%' THEN 'restaurant'
      ELSE 'non-restaurant'
    END AS vertical_group,
    CASE 
      WHEN p.metodo_pago = 'Cash_orders' OR LOWER(p.metodo_pago) LIKE '%cash%' THEN 'cash'
      ELSE 'online + COD'
    END AS pago_group,
    CASE 
      WHEN p.metodo_pago = 'Cash_orders' OR LOWER(p.metodo_pago) LIKE '%cash%' THEN 1
      ELSE 0
    END AS is_cash,
    CASE
      WHEN p.order_value < 10000 THEN '01. 0 - 10k'
      WHEN p.order_value < 20000 THEN '02. 10k - 20k'
      WHEN p.order_value < 30000 THEN '03. 20k - 30k'
      WHEN p.order_value < 40000 THEN '04. 30k - 40k'
      WHEN p.order_value < 50000 THEN '05. 40k - 50k'
      WHEN p.order_value < 60000 THEN '06. 50k - 60k'
      ELSE '07. 60k+'
    END AS bucket_afv,
    CASE WHEN b.is_split = TRUE THEN 1 ELSE 0 END AS is_split,
    COALESCE(b.deliveries_netos, 1) AS deliveries_netos,
    p.order_completed,
    p.order_cancelled,
    p.DT AS dt,
    p.is_seamless,
    p.orders_count_seamless,
    p.is_ol,
    p.is_ol_cf,
    CASE WHEN c.order_id IS NOT NULL THEN 1 ELSE 0 END AS has_cod_chat,
    p.order_code
  FROM `peya-argentina.automated_tables_reports.pay_at_pu` AS p
  LEFT JOIN `peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance` AS b
    ON b.order_code = p.order_code
    AND b.date = p.date
  LEFT JOIN RiderChatsCOD AS c
    ON c.order_id = p.order_code
  WHERE p.date >= dInf AND p.date <= dSup
)

SELECT
  date,
  city_name,
  city_group,
  vertical_group,
  pago_group,
  bucket_afv AS bucket,
  COUNT(DISTINCT order_code) AS total_orders,
  COUNT(DISTINCT CASE WHEN order_completed = 1 THEN order_code END) AS completed_orders,
  COUNT(DISTINCT CASE WHEN order_cancelled = 1 THEN order_code END) AS cancelled_orders,
  
  -- Split Orders (estrictamente a nivel órdenes y entregas)
  COUNT(DISTINCT CASE WHEN is_split = 1 THEN order_code END) AS split_orders,
  SUM(is_split) AS sum_split_deliveries,
  SUM(deliveries_netos) AS sum_deliveries_netos,
  
  -- Split Orders Cash
  COUNT(DISTINCT CASE WHEN is_cash = 1 THEN order_code END) AS cash_orders,
  COUNT(DISTINCT CASE WHEN is_cash = 1 AND is_split = 1 THEN order_code END) AS cash_split_orders,
  
  -- Contact Rate: Chats de Rider por falta de efectivo / problema COD
  COUNT(DISTINCT CASE WHEN has_cod_chat = 1 THEN order_code END) AS cod_contact_orders,
  COUNT(DISTINCT CASE WHEN is_cash = 1 AND has_cod_chat = 1 THEN order_code END) AS cash_cod_contact_orders,
  
  -- Tasas de Contact Rate calculadas
  SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN has_cod_chat = 1 THEN order_code END), COUNT(DISTINCT order_code)) * 100 AS contact_rate_cod_pct,
  SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN is_cash = 1 AND has_cod_chat = 1 THEN order_code END), COUNT(DISTINCT CASE WHEN is_cash = 1 THEN order_code END)) * 100 AS contact_rate_cod_cash_pct,
  
  -- Key Operations & Quality Metrics
  COUNT(DISTINCT CASE WHEN is_ol = 1 THEN order_code END) AS ol_orders,
  COUNT(DISTINCT CASE WHEN is_ol_cf = 1 THEN order_code END) AS ol_cf_orders,
  COUNT(DISTINCT CASE WHEN is_seamless = '1' THEN order_code END) AS seamless_orders,
  COUNT(DISTINCT CASE WHEN orders_count_seamless IS NOT NULL THEN order_code END) AS seamless_base_orders,
  AVG(dt) AS avg_dt
FROM RawOrders
GROUP BY ALL
ORDER BY date DESC, city_name, bucket;
