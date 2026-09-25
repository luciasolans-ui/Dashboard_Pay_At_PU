DECLARE dInf DATE;
DECLARE dSup DATE;
SET dInf = '2026-09-16'; -- Fecha oficial de inicio del test (Miércoles 16/Sep)
SET dSup = CURRENT_DATE(); -- Fecha de fin (incluida)

WITH Deliveries AS (
  SELECT 
    o.platform_order_code AS order_code,
    MAX(d.stacked_deliveries) AS stacked_deliveries,
    vendor.vertical_type,
    MAX(o.capacity) AS capacity,
    MAX(o.original_scheduled_pickup_at) AS commited_pickup_at,
    MAX(o.created_at) AS creation_time,
    MAX(o.timings.at_vendor_time) AS at_vendor_time,
  FROM `fulfillment-dwh-production.curated_data_shared.orders` AS o
  LEFT JOIN UNNEST(deliveries) AS d
  WHERE
    -- Se extrae desde 28 días antes de dInf para cubrir el Baseline L4W completo (inclusive)
    DATETIME(o.created_at, o.timezone) >= DATETIME(DATE_SUB(dInf, INTERVAL 28 DAY))
    AND DATETIME(o.created_at, o.timezone) <= DATETIME(dSup)
    AND o.created_date BETWEEN DATE_SUB(dInf, INTERVAL 29 DAY) AND dSup + 1
    AND o.country_code = 'ar'
  GROUP BY ALL
),

CPO AS (
  SELECT
    country_code,
    platform_order_code AS order_code,
    SUM(basic_payment_per_km_pu_lc) AS pago_distancia_pu,
    SUM(basic_payment_per_del_pud_lc) AS pago_pu,
    SUM(basic_payment_per_km_do_lc) AS pago_distancia_do,
    SUM(basic_payment_per_del_ndo_lc) AS pago_do,
    SUM(basic_cpo_lc) AS pago_base_base,
    SUM(scoring_cpo_lc) AS pago_scoring,
    (SUM(basic_cpo_lc) + SUM(scoring_cpo_lc)) AS pago_base,
  FROM `peya-datamarts-pro.dm_cpo.overall_cpo`
  WHERE
    created_date >= DATE_SUB(dInf, INTERVAL 28 DAY)
    AND created_date <= dSup
    AND country_code = 'ar'
  GROUP BY ALL
),

Stacking AS (
  SELECT
    -- SAFE_CAST en los joins para garantizar alineación estricta de tipos de datos en BigQuery
    SAFE_CAST(order_code AS STRING) AS order_code,
    rank_delivery,
    Good_stacking,
    stacking_format,
    stack_group,
    dif_PU_Times AS delta_PU
  FROM `peya-argentina.automated_tables_reports.stacking_groups_dataset`
  WHERE created_date BETWEEN DATE_SUB(dInf, INTERVAL 29 DAY) AND dSup + 1
  GROUP BY ALL
),

LateOrders AS (
  SELECT
    o.order_code,
    -- 1. OL Operativo > 10': Retraso > 10 minutos (600 seg) respecto a la estimación operativa interna de Hurrier
    CASE WHEN o.rider.order_status = 'completed' AND o.rider.timings.order_delay > 600 THEN 1 ELSE 0 END AS is_ol,
    -- 2. OL Customer Facing (CF): Entrega completada con tiempo real superior a la promesa máxima informada al consumidor en la app (actual_delivery_time > PDT Max)
    CASE WHEN o.rider.order_status = 'completed' AND (o.rider.timings.actual_delivery_time > fo.promiseddeliverytime.maxMinutes * 60) THEN 1 ELSE 0 END AS is_ol_cf
  FROM `peya-data-origins-pro.cl_hurrier.orders_v2` AS o
  LEFT JOIN `peya-bi-tools-pro.il_core.fact_orders` AS fo
    ON CAST(fo.order_id AS STRING) = o.order_code
    AND fo.registered_date >= DATE_SUB(dInf, INTERVAL 28 DAY)
    AND fo.registered_date <= dSup
    AND fo.country_id = 3
  WHERE o.created_date >= DATE_SUB(dInf, INTERVAL 28 DAY)
    AND o.created_date <= dSup
    AND o.entity.id = 'PY_AR' -- Mapeo oficial de Argentina para orders_v2
),

RiderChats AS (
  SELECT
    order_id,
    COUNT(DISTINCT chat_id) AS total_rider_chats,
    COUNT(DISTINCT CASE WHEN contact_reason_l3 = 'COD issue' THEN chat_id END) AS total_cod_chats
  FROM `peya-data-origins-pro.cl_gcc_service.pandacare_chats`
  WHERE created_date BETWEEN DATE_SUB(dInf, INTERVAL 29 DAY) AND dSup + 1
    AND created_date_localtime >= DATE_SUB(dInf, INTERVAL 28 DAY)
    AND created_date_localtime <= dSup
    AND global_entity_id = 'PY_AR'
    AND stakeholder = 'Rider'
  GROUP BY 1
),

LogisticsOrders AS (
  SELECT
    platform_order_code AS order_code,
    timings.avoidable_wait_time
  FROM `peya-bi-tools-pro.il_logistics.fact_logistic_orders`
  WHERE created_date BETWEEN DATE_SUB(dInf, INTERVAL 29 DAY) AND dSup + 1
    AND country_code = 'ar'
)

SELECT
  b.date,
  b.date_time,
  b.hour,
  b.rider_id,
  b.compliance_segment,
  b.regional_segment,
  b.batch,
  b.order_code,
  CASE WHEN vertical IN ('Courier','Courier Business') THEN NULL ELSE b.order_code END AS orders_count_seamless,
  b.partner_name,
  b.franchise_name,
  b.vertical,
  d.vertical_type,
  CASE WHEN reject_message = 'CONFIRMED' THEN b.is_stacked ELSE NULL END AS is_stacked,

  -- COALESCE para evitar nulos y asegurar el procesamiento correcto de los niveles de stacking (0, 2, 3+)
  COALESCE(CASE WHEN (d.stacked_deliveries IS NULL OR d.stacked_deliveries = 0) THEN 0 ELSE d.stacked_deliveries + 1 END, 0) AS stacked_deliveries,
  d.capacity,
  b.city_name,
  b.cancellation_reason,
  b.reject_message,
  CASE WHEN b.reject_message NOT IN ('CONFIRMED') THEN 1 ELSE 0 END AS order_cancelled,
  CASE WHEN b.reject_message IN ('CONFIRMED') THEN 1 ELSE 0 END AS order_completed,
  b.accionador_level1,
  b.order_value,
  b.metodo_pago,
  b.mean_delay,
  b.bucket_MD,
  b.is_pin_validation,
  b.last_state_anterior,
  FORMAT_DATETIME('%Y-%m-%d %H:%M:%S', DATETIME(d.commited_pickup_at, 'America/Argentina/Buenos_Aires')) AS commited_pickup_at,
  CAST(d.at_vendor_time AS FLOAT64) AS at_vendor_time,
  b.actual_delivery_time AS DT,

  TIMESTAMP_DIFF(d.commited_pickup_at, d.creation_time, MINUTE) AS commitment_time_mins,

  b.Orders_Notified AS notificadas,
  b.decline,
  b.not_seen,
  b.ignore_,
  (b.decline + b.not_seen + b.ignore_) AS undispatchs_pre,
  b.order_issue,
  b.late_prep,
  b.accident,
  b.equipment_issue,
  (b.courier_did_not_hit_pu + b.pu_nogps_delayed + b.not_moving_pu + b.waiting_at_pu) AS ICE_undispatchs,
  b.dispatcher_undispatchs,
  (b.order_issue + b.late_prep + b.accident + b.equipment_issue + b.courier_did_not_hit_pu + b.pu_nogps_delayed + b.not_moving_pu + b.waiting_at_pu + b.dispatcher_undispatchs) AS undispatchs_post,
  -- Unified Total Undispatches
  (b.decline + b.not_seen + b.ignore_ + b.order_issue + b.late_prep + b.accident + b.equipment_issue + b.courier_did_not_hit_pu + b.pu_nogps_delayed + b.not_moving_pu + b.waiting_at_pu + b.dispatcher_undispatchs) AS undispatchs_total,

  -- SEAMLESS (Se mantienen separados e independientes session y modified de origen)
  b.Seamless_is_slow_order,
  b.Seamless_is_late_order,
  b.Seamless_is_session_order,
  b.Seamless_is_rejected_order,
  b.Seamless_is_modified_order,
  b.Seamless_is_forced_order,
  CASE WHEN b.Seamless_seamless_order = TRUE THEN b.order_code ELSE NULL END AS is_seamless,

  -- Food Delivery Accuracy (FDA) Fields & Explicit Formula Calculation
  b.FDA_wastage_amount_num,
  b.FDA_recupero_wastage_amount_num,
  b.FDA_refund_amount_num,
  b.FDA_recupero_refund_amount_num,
  b.FDA_compensation_amount_num,
  -- Formula explícita de FDA: wastage - recupero_wastage + refund - recupero_refund + compensation
  (
    COALESCE(b.FDA_wastage_amount_num, 0) - COALESCE(b.FDA_recupero_wastage_amount_num, 0) +
    COALESCE(b.FDA_refund_amount_num, 0) - COALESCE(b.FDA_recupero_refund_amount_num, 0) +
    COALESCE(b.FDA_compensation_amount_num, 0)
  ) AS FDA_cost_amount,

  -- Cost Per Order (CPO) Fields
  cpo.pago_distancia_pu,
  cpo.pago_pu,
  cpo.pago_distancia_do,
  cpo.pago_do,
  cpo.pago_base_base,
  cpo.pago_scoring,
  cpo.pago_base,

  -- Inaccuracy DWH Columns
  IFNULL(b.missing_item,0) AS missing_item,
  IFNULL(b.wrong_item,0) AS wrong_item,
  IFNULL(b.wrong_order,0) AS wrong_order,
  IFNULL(b.food_quality,0) AS food_quality,
  IFNULL(b.inac_num,0) AS inac_num,

  -- Stacking Groups Joined Fields (Casting STRING de alineación en DWH)
  stack.Good_stacking,
  stack.rank_delivery,
  stack.stacking_format,
  stack.stack_group,
  stack.delta_PU,

  -- Order Late Variables (OL > 10' y OL CF)
  COALESCE(lo.is_ol, 0) AS is_ol,
  COALESCE(lo.is_ol_cf, 0) AS is_ol_cf,

  -- Split Orders Fields
  CASE WHEN b.is_split = TRUE THEN 1.0 ELSE 0.0 END AS is_split,
  COALESCE(b.deliveries_netos, 1) AS deliveries_netos,
  CASE
    WHEN b.order_value < 10000 THEN '01. 0 - 10k'
    WHEN b.order_value < 20000 THEN '02. 10k - 20k'
    WHEN b.order_value < 30000 THEN '03. 20k - 30k'
    WHEN b.order_value < 40000 THEN '04. 30k - 40k'
    WHEN b.order_value < 50000 THEN '05. 40k - 50k'
    WHEN b.order_value < 60000 THEN '06. 50k - 60k'
    ELSE '07. 60k+'
  END AS bucket_afv,

  -- Contact Rate Metrics:
  -- 1. Contact Rate General: Cantidad de veces que los riders establecieron contacto con soporte (cualquier motivo)
  COALESCE(c.total_rider_chats, 0) AS rider_chats_total,
  -- 2. Contact Rate Cash: Motivo COD issue (caja insuficiente / falta de efectivo)
  CASE WHEN c.total_cod_chats > 0 THEN 1.0 ELSE 0.0 END AS has_cod_chat,

  -- Avoidable Wait Time (AWT > 5 min / > 300 segundos)
  log.avoidable_wait_time,
  CASE WHEN log.avoidable_wait_time > 300 THEN 1 ELSE 0 END AS is_awt_gt_5,
  CASE WHEN log.avoidable_wait_time IS NOT NULL THEN 1 ELSE 0 END AS has_awt

FROM `peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance` AS b
LEFT JOIN Deliveries AS d ON d.order_code = b.order_code
LEFT JOIN CPO AS cpo ON cpo.order_code = b.order_code
LEFT JOIN Stacking AS stack ON SAFE_CAST(b.order_code AS STRING) = SAFE_CAST(stack.order_code AS STRING)
LEFT JOIN LateOrders AS lo ON SAFE_CAST(b.order_code AS STRING) = SAFE_CAST(lo.order_code AS STRING)
LEFT JOIN RiderChats AS c ON c.order_id = b.order_code
LEFT JOIN LogisticsOrders AS log ON log.order_code = b.order_code
WHERE
  -- Se amplía la partición temporal en la consulta principal para incluir las últimas 4 semanas de baseline (inclusive)     
  date >= DATE_SUB(dInf, INTERVAL 28 DAY) AND date <= dSup

  -- FILTRO DE CIUDADES OFICIALES DE TEST:
  AND city_name IN ('Rafaela','San salvador de jujuy')

  -- EXCLUSIONES HORARIAS:
  -- Excluir Sábado 12 de Septiembre de 2026 entre las 21:00 hs y las 23:59 hs (inclusive)
  AND NOT (date = '2026-09-12' AND CAST(b.hour AS INT64) BETWEEN 21 AND 23)
  -- Excluir Domingo 13 de Septiembre de 2026 entre las 00:00 hs y las 03:00 hs (inclusive)
  AND NOT (date = '2026-09-13' AND CAST(b.hour AS INT64) BETWEEN 0 AND 3)
GROUP BY ALL;
