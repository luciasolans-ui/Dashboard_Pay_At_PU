# Dashboard Pay at Pickup — Documentación y Handover (Actualizado al 2026-09-24)

Este repositorio contiene el código fuente, la infraestructura de despliegue para **Google Apps Script** y la consulta SQL analítica en **BigQuery** para el experimento de capacidad y stacking **"Pay at Pickup"** (Rafaela y Jujuy), iniciado el 16 de septiembre de 2026.

---

## 1. Enlaces Oficiales

*   **Web App Corporativa (Apps Script):**
    👉 **[https://script.google.com/macros/s/AKfycbxi-R8MrkuzSUvlJ5NDlvksIykhP2nOG-E70F7AaSxQsBG2lcpWELBJgMgiRILn6hYz/exec](https://script.google.com/macros/s/AKfycbxi-R8MrkuzSUvlJ5NDlvksIykhP2nOG-E70F7AaSxQsBG2lcpWELBJgMgiRILn6hYz/exec)**
*   **Repositorio GitHub:** `https://github.com/luciasolans-ui/Dashboard_Pay_At_PU.git`
*   **Despliegue Activo:** Versión `@18` sobre Deployment ID `AKfycbxi-R8MrkuzSUvlJ5NDlvksIykhP2nOG-E70F7AaSxQsBG2lcpWELBJgMgiRILn6hYz`.

---

## 2. Métricas Consolidadas del Experimento (16/09 al 24/09/2026)

*   **Universo Total:** **131,995 órdenes** (del 19 de agosto al 24 de septiembre de 2026 inclusive).
*   **Órdenes Completadas Test:** **31,902**
*   **Stacking General:** **39.75%** (vs 33.15% L4W, +6.6 pp / +19.9%)
*   **Fail Rate (FR):** **1.51%** (vs 1.83% L4W, -0.3 pp / -17.5%)
*   **OL Operativo (> 10 min):** **14.04%** (vs 13.00% L4W)
*   **OL CF (Customer Facing):** **16.29%** (vs 15.43% L4W)
*   **Delivery Time (DT):** **26.15 min** (vs 25.10 min L4W)
*   **CPO Base Base:** **$2,324.96** (vs $2,246.30 L4W)
*   **Undispatched Total:** **14.88%** (vs 13.48% L4W)
*   **Committed PU (Wait Time):** **12.92 min** (vs 13.67 min L4W)
*   **Split Orders Total:** **0.47%** (vs 0.58% L4W)
*   **Split Orders Cash:** **1.70%** (vs 1.95% L4W)
*   **FDA Costo Unitario:** **$134.12** (vs $125.44 L4W)
*   **Contact Rate Total:** **2.33%** (vs 1.54% L4W)
*   **Contact Rate Cash (COD):** **1.26%** (vs 1.07% L4W)
*   **AWT > 5 min:** **13.68%** (vs 14.82% L4W, -1.14 pp / -7.7%)
*   **Seamless Total:** **87.05%** (vs 88.54% L4W)

---

## 3. Scorecard Ejecutivo (2 Filas / 11 Tarjetas)

1.  **Completed Orders**
2.  **Stacking General**
3.  **Seamless Total**
4.  **Fail Rate (FR)**
5.  **Delivery Time (DT)**
6.  **CPO Base Base**
7.  **OL Operativo (> 10 min)**
8.  **OL CF (Customer Facing)**
9.  **Undispatched Total**
10. **AWT > 5 min (Evitable)**
11. **Contact Rate Total (CR%)**

---

## 4. Pipeline y Automatización

*   **Tabla Fuente Automatizada:** `peya-argentina.automated_tables_reports.pay_at_pu` (actualizada diariamente a las 10:55 AM).
*   **Disparador en Apps Script:** Time-driven Trigger programado para ejecutarse diariamente entre las 11:00 AM y las 12:00 PM ART.
