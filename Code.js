/**
 * Google Apps Script - Pay at Pickup Dashboard Controller
 * Consume directamente desde la tabla oficial `peya-argentina.automated_tables_reports.pay_at_pu`
 */

function doGet() {
  return HtmlService.createHtmlOutputFromFile('Pay_at_PU')
    .setTitle('Pay at Pickup - Capacidad, Stacking, Split Orders & Contact Rate')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL)
    .addMetaTag('viewport', 'width=device-width, initial-scale=1');
}

/**
 * Consulta y devuelve directamente los registros desde la tabla oficial automatizada `pay_at_pu`.
 */
function getPayAtPuDataFromBigQuery() {
  const projectId = 'peya-argentina';
  const query = 'SELECT * FROM `peya-argentina.automated_tables_reports.pay_at_pu` ORDER BY date DESC, city_name, bucket';

  const request = {
    query: query,
    useLegacySql: false,
    timeoutMs: 60000
  };

  const queryResults = BigQuery.Jobs.query(request, projectId);
  if (!queryResults.rows) return [];

  const fields = queryResults.schema.fields.map(f => f.name);
  return queryResults.rows.map(row => {
    const obj = {};
    row.f.forEach((cell, idx) => {
      obj[fields[idx]] = cell.v;
    });
    return obj;
  });
}

/**
 * Función de actualización diaria programada.
 * Consulta la tabla oficial automatizada `peya-argentina.automated_tables_reports.pay_at_pu`
 * (actualizada a las 10:55 AM) para consolidar los datos del experimento.
 */
function updateDashboardDataDaily() {
  console.log('Iniciando sincronización diaria directa desde peya-argentina.automated_tables_reports.pay_at_pu...');
  try {
    const data = getPayAtPuDataFromBigQuery();
    PropertiesService.getScriptProperties().setProperty('LAST_SYNC_TIMESTAMP', new Date().toISOString());
    PropertiesService.getScriptProperties().setProperty('TOTAL_ROWS_SYNCED', String(data.length));
    console.log('Sincronización diaria completada con éxito. Filas procesadas: ' + data.length);
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
