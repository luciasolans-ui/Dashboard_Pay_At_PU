# 🛵 Pay at Pickup - Dashboard de Experimento de Capacidad & Stacking

Dashboard interactivo de alta fidelidad y pipeline de datos para el seguimiento, monitoreo y evaluación del experimento logístico **"Pay at Pickup"** en las ciudades de **Rafaela** y **San Salvador de Jujuy** (PedidosYa Argentina), iniciado el **miércoles 16 de septiembre de 2026**.

---

## 🌐 Enlaces de Acceso Rápido

*   **Web App Corporativa (Google Apps Script):**  
    👉 **[Abrir Dashboard en Google Apps Script](https://script.google.com/macros/s/AKfycbxi-R8MrkuzSUvlJ5NDlvksIykhP2nOG-E70F7AaSxQsBG2lcpWELBJgMgiRILn6hYz/exec)**  
    *(Requiere inicio de sesión con cuenta corporativa `@pedidosya.com`).*
*   **Visualización Local:**  
    Descargar o clonar este repositorio y abrir el archivo `Pay_at_PU.html` directamente en cualquier navegador moderno (Google Chrome, Microsoft Edge, Firefox):
    ```bash
    # En Windows (PowerShell / CMD)
    start Pay_at_PU.html
    ```

---

## 📊 Arquitectura del Dashboard

El dashboard es una solución autocontenida y optimizada que procesa **122,877 órdenes reales de BigQuery** consolidadas en una matriz multidimensional de **4,836 registros compactos**, permitiendo tiempos de respuesta de filtrado instantáneos (< 50 ms) en el cliente.

### Componentes Clave:
1.  **Scorecard Ejecutivo (8 KPIs Principales):**
    *   **Completed Orders**
    *   **Stacking General (%)**
    *   **Seamless Total (%)**
    *   **Fail Rate (FR %)**
    *   **OL y OL CF (%)**
    *   **Undispatched Total (%)**
    *   **CPO Base Base ($)**
    *   **Delivery Time (DT en minutos)**
2.  **Filtros Globales Interactivos:**
    *   **Ciudad:** Cities del testeo (Rafaela + Jujuy), Rafaela individual, Jujuy individual.
    *   **Vertical:** Restaurant (Default), Non-Restaurant, Todas las Verticales.
    *   **Método de Pago:** Online + COD sin desembolso (Default), Cash (Efectivo en PU), Todos los Pagos.
    *   **Día de la Semana:** Todos o filtrado específico por día (Lunes a Domingo).
    *   **Agrupación Temporal:** Semanal WoW (`W34` a `W38`) o Día a Día DoD (`16/Sep`, `17/Sep`, etc.).
    *   **Range Slider de Max Mean Delay:** Control dinámico en tiempo real para acotar el eje X (4 a 20 min).
3.  **10 Paneles Detallados de Métricas con Doble Visualización:**
    *   **Gráfico Izquierdo (Evolución Temporal):** Evolución temporal WoW / DoD con segmentación dinámica de color (Gris `#94A3B8` para baseline L4W y Rojo `#EA044E` para período de test).
    *   **Gráfico Derecho (Distribución por Mean Delay):** Comparativa de Test vs. Baseline histórico L4W Match matcheando días idénticos de las 4 semanas previas, con eje secundario opcional de *Share de Órdenes (%)*.

---

## 🎯 Sección 7: OL Operativo vs. OL Customer Facing (CF)

Una de las incorporaciones clave del dashboard es la doble curva de Order Late para monitorear tanto la eficiencia operativa interna como la experiencia real percibida por el cliente:

| Métrica | Enfoque | Condición Técnica (BigQuery SQL) | Significado de Negocio |
| :--- | :--- | :--- | :--- |
| **OL Operativo (> 10 min)** | **Eficiencia de Flota Interna** | `o.rider.order_status = 'completed' AND o.rider.timings.order_delay > 600` | Demoras mayores a 10 minutos (600 s) respecto al tiempo estimado calculado por el motor de despacho de Hurrier. |
| **OL CF (Customer Facing)** | **Cumplimiento de Promesa (RvR)** | `o.rider.order_status = 'completed' AND (o.rider.timings.actual_delivery_time > fo.promiseddeliverytime.maxMinutes * 60)` | Incumplimiento de cara al usuario final: pedidos cuya entrega superó la cota máxima del tiempo prometido en la app durante el checkout (`actual_delivery_time > PDT Max`). |

### Fórmulas de Tasa:
$$\%OL\text{ Operativo} = \frac{\sum \text{Órdenes completadas con } (order\_delay > 600\text{ s})}{\text{Total de órdenes completadas}} \times 100$$

$$\%OL\text{ CF} = \frac{\sum \text{Órdenes completadas con } (actual\_delivery\_time > PDT\_max)}{\text{Total de órdenes completadas}} \times 100$$

*El panel cuenta con selectores de tipo checkbox en la cabecera para alternar independientemente la visualización de ambas curvas (`OL (> 10 min)` en `#EA044E` y `OL CF` en `#04ADDF`).*

---

## 🗄️ Consulta SQL (`query_pay_at_pickup.sql`)

La consulta extrae y consolida las órdenes logísticas cruzando las tablas oficiales de PedidosYa y Delivery Hero:

*   `peya-argentina.automated_tables_reports.DETALLE_ORDENES_rider_Performance AS b`: Tabla base local de órdenes de Argentina.
*   `peya-data-origins-pro.cl_hurrier.orders_v2 AS o`: Timings exactos de despacho, desvíos y estados de flota.
*   `peya-bi-tools-pro.il_core.fact_orders AS fo`: Promesa máxima al cliente (`promiseddeliverytime.maxMinutes`) para cálculo de OL CF.
*   `fulfillment-dwh-production.curated_data_shared.orders AS d`: Stacking deliveries y capacidad de locales.
*   `peya-datamarts-pro.dm_cpo.overall_cpo AS cpo`: Desglose granular de costos por orden (pago PU, DO, distancia y base).
*   `peya-argentina.automated_tables_reports.stacking_groups_dataset AS stack`: Agrupaciones curadas y Good Stacking.

### Filtros y Particiones Obligatorias:
*   **Período:** Desde `DATE_SUB(dInf, INTERVAL 28 DAY)` hasta `CURRENT_DATE()` (inclusive).
*   **Ciudades:** `city_name IN ('Rafaela', 'San salvador de jujuy')`.
*   **Exclusiones de Vertical:** Se omiten verticales de mensajería (`Courier` y `Courier Business`).
*   **Exclusiones Horarias Específicas:**
    *   Sábado 12 de septiembre de 2026 entre las 21:00 hs y las 23:59 hs.
    *   Domingo 13 de septiembre de 2026 entre las 00:00 hs y las 03:00 hs.

---

## 📁 Estructura del Repositorio

```text
├── Pay_at_PU.html               # Dashboard autocontenido con datos reales embebidos
├── query_pay_at_pickup.sql      # Consulta analítica completa en BigQuery SQL
├── Code.js                      # Controlador de entrada para Google Apps Script
├── appsscript.json              # Configuración y manifiesto de Apps Script
├── README.md                    # Documentación del proyecto
└── .gitignore                   # Archivos ignorados por Git
```

---

## 👥 Colaboradores y Contacto

*   **Lucia Solans** (`lucia.solans@pedidosya.com`) - Data & Logistics Analytics
*   **Julian Boglio** (`julian.boglio@pedidosya.com`)
*   **Martin Jaremczuk** (`martin.jaremczuk@pedidosya.com`)

Dirección de Operaciones & Logistics Analytics — PedidosYa Argentina © 2026
