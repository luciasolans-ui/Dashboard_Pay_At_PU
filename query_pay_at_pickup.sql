-- Consulta oficial sobre la tabla automatizada de Pay at Pickup
-- Tabla fuente: peya-argentina.automated_tables_reports.pay_at_pu (actualización diaria: 10:55 AM)
SELECT
  p.*,
  CASE WHEN b.is_split = TRUE THEN 1.0 ELSE 0.0 END AS is_split,
  COALESCE(b.deliveries_netos, 1) AS deliveries_netos,
  CASE
    WHEN p.order_value < 10000 THEN '01. 0 - 10k'
    WHEN p.order_value < 20000 THEN '02. 10k - 20k'
    WHEN p.order_value < 30000 THEN '03. 20k - 30k'
    WHEN p.order_value < 40000 THEN '04. 30k - 40k'
    WHEN p.order_value < 50000 THEN '05. 40k - 50k'
    WHEN p.order_value < 60000 THEN '06. 50k - 60k'
    ELSE '07. 60k+'
  END AS bucket_afv
FROM `peya-argentina.automated_tables_reports.pay_at_pu` AS p
LEFT JOIN `peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance` AS b
  ON b.order_code = p.order_code
  AND b.date = p.date;
