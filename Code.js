/**
 * Google Apps Script - Pay at Pickup Dashboard Controller
 * Incluye servidor Web App, automatización de consultas BigQuery y disparador programado diario.
 */

function doGet() {
  return HtmlService.createHtmlOutputFromFile('Pay_at_PU')
    .setTitle('Pay at Pickup - Capacidad, Stacking, Split Orders & Contact Rate')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

/**
 * Función de actualización diaria programada.
 * Consulta la tabla oficial automatizada `peya-argentina.automated_tables_reports.pay_at_pu`
 * (actualizada a las 10:55 AM) y cruza con `pandacare_chats` para consolidar los datos del experimento.
 */
function updateDashboardDataDaily() {
  console.log('Iniciando actualización diaria desde peya-argentina.automated_tables_reports.pay_at_pu...');
  
  const projectId = 'peya-argentina';
  const query = `
    WITH RiderChatsCOD AS (
      SELECT
        order_id,
        COUNT(DISTINCT chat_id) AS total_cod_chats
      FROM \`peya-data-origins-pro.cl_gcc_service.pandacare_chats\`
      WHERE created_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 35 DAY)
        AND global_entity_id = 'PY_AR'
        AND stakeholder = 'Rider'
        AND contact_reason_l3 = 'COD issue'
      GROUP BY 1
    )
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
      END AS bucket_afv,
      CASE WHEN c.order_id IS NOT NULL THEN 1.0 ELSE 0.0 END AS is_cod_chat
    FROM \`peya-argentina.automated_tables_reports.pay_at_pu\` AS p
    LEFT JOIN \`peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance\` AS b
      ON b.order_code = p.order_code
      AND b.date = p.date
    LEFT JOIN RiderChatsCOD AS c
      ON c.order_id = p.order_code;
  `;

  try {
    const request = {
      query: query,
      useLegacySql: false,
      timeoutMs: 120000
    };
    
    const queryResults = BigQuery.Jobs.query(request, projectId);
    console.log('Job de BigQuery ejecutado exitosamente. Total de filas procesadas: ' + queryResults.totalRows);
    
    // Almacena timestamp de última actualización exitosa en Script Properties
    PropertiesService.getScriptProperties().setProperty('LAST_SYNC_TIMESTAMP', new Date().toISOString());
    PropertiesService.getScriptProperties().setProperty('TOTAL_ROWS_SYNCED', String(queryResults.totalRows));
    console.log('Actualización diaria completada correctamente.');
  } catch (err) {
    console.error('Error al actualizar datos desde BigQuery: ' + err.message);
    throw err;
  }
}

/**
 * Función que programa el disparador activado por tiempo (Time-driven Trigger).
 * Se ejecuta una vez al día en la ventana entre las 11:00 AM y las 12:00 PM (hora de Buenos Aires),
 * garantizando que corra inmediatamente después de que finalice la actualización de la tabla a las 10:55 AM.
 */
function createDailyTrigger() {
  const existingTriggers = ScriptApp.getProjectTriggers();
  existingTriggers.forEach(trigger => {
    if (trigger.getHandlerFunction() === 'updateDashboardDataDaily') {
      ScriptApp.deleteTrigger(trigger);
    }
  });

  ScriptApp.newTrigger('updateDashboardDataDaily')
    .timeBased()
    .everyDays(1)
    .atHour(11) // Ventana de 11:00 AM a 12:00 PM (después de las 10:55 AM)
    .inTimezone('America/Argentina/Buenos_Aires')
    .create();

  console.log('✅ Trigger programado con éxito: Se ejecutará todos los días entre 11:00 AM y 12:00 PM (ART).');
}
