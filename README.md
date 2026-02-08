# Valorización de Análisis de Laboratorio – PAMI & APROSS

Aplicación Shiny para la valorización automática de prácticas bioquímicas a partir de archivos Excel exportados de sistemas de gestión de laboratorio.

El proyecto contiene dos aplicaciones independientes:

- `pami/` → Valorización según nomenclador y reglas de PAMI  
- `apross/` → Valorización según nomenclador y reglas de APROSS  

Cada app implementa:
- Conteo real de análisis por afiliado
- Aplicación de umbrales por volumen
- Excepciones por códigos especiales
- Tratamiento independiente del acto bioquímico
- Exportación a Excel, CSV, PDF

---

## Lógica de cálculo

La valorización se basa en el **total de análisis por afiliado dentro del período cargado**, no por orden individual.

Ejemplo Para PAMI (para APROSS tiene reglas mas específicas):

Un afiliado realiza:
- 6 análisis el 06/08
- 6 análisis el 28/08  

El sistema lo trata como **12 análisis**, aplicando el umbral correspondiente a 12 para **todos los análisis** (excepto el acto bioquímico).

Esto refleja el criterio real de facturación por volumen mensual.

---

## Funcionalidades principales

- Carga de archivos Excel (lotes diarios, quincenales o mensuales)
- Recuento automático por afiliado
- Umbral único aplicado a todos los análisis del afiliado
- Acto bioquímico valorizado por fuera
- Excepciones:
  - Mediana frecuencia
  - Alta frecuencia
  - Alta complejidad
- Tabla detallada por práctica
- Resumen total por afiliado
- Exportación a Excel / CSV / PDF

---

## Estructura del repositorio

