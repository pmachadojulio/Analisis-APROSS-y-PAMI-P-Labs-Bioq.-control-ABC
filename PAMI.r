# Cargar bibliotecas
library(shiny)
library(dplyr)
library(DT)
library(openxlsx)

# Función para transformar los nombres de las columnas
transformar_nombres_columnas <- function(df) {
  names(df) <- case_when(
    names(df) == "num_carnet" ~ "AFILIADO",
    names(df) == "fec_fac" ~ "FECHA",
    names(df) == "codigo_fac" ~ "CODIGO",
    names(df) == "item" ~ "RECUENTO_ITEM",
    names(df) == "uni_gas" ~ "CANT. NBU",
    TRUE ~ names(df)
  )

  df$CODIGO <- sub("^66", "", df$CODIGO)  # Quitar el "66" al principio de CODIGO
  return(df)
}

# Define la interfaz de usuario
ui <- fluidPage(
  fileInput("data_file", "Cargar archivo Excel", accept = c(".xlsx")),
  numericInput("rango1_7", "Valor para 1-7 análisis:", value = 153.5),
  numericInput("rango8_mas", "Valor para 8+ análisis:", value = 116),
  numericInput("valor_acto_bioquimico", "Valor del Acto Bioquímico:", value = 9),
  actionButton("generate_button", "GENERAR"),
  DTOutput("result_table")
)

# Define el servidor
server <- function(input, output, session) {
  data <- reactiveVal(NULL)
  data_result <- reactiveVal(NULL)

  observeEvent(input$data_file, {
    # Cargar datos cuando se selecciona un archivo y transformar nombres de columnas
    data(transformar_nombres_columnas(read.xlsx(input$data_file$datapath)))
  })

  observeEvent(input$generate_button, {
    # Ejecutar el código cuando se hace clic en el botón "GENERAR"
    if (!is.null(data())) {
      # Obtener los valores de las reglas ingresados por el usuario
      valores_reglas <- c(
        rango1_7 = input$rango1_7,
        rango8_mas = input$rango8_mas
      )

      # Calcular el umbral más alto alcanzado por cada AFILIADO
      umbrales <- data() %>%
        group_by(AFILIADO) %>%
        summarize(max_recuento = max(RECUENTO_ITEM, na.rm = TRUE))

      # Unir los umbrales al conjunto de datos original
      data_with_umbral <- left_join(data(), umbrales, by = "AFILIADO")

      # Calcular el recuento por AFILIADO y asignar como nuevo RECUENTO_ITEM
      data_with_recuento <- data_with_umbral %>%
        group_by(AFILIADO) %>%
        mutate(RECUENTO_ITEM = row_number())

      # Ordenar las prácticas de cada afiliado según las unidades bioquímicas (CANT. NBU)
      data_sorted <- data_with_recuento %>%
        arrange(AFILIADO, `CANT. NBU`)

      # Aplicar la función de cálculo de importe con los valores ingresados y el umbral más alto
      data_result_val <- data_sorted %>%
        mutate(
          IMPORTE = `CANT. NBU` * case_when(
            RECUENTO_ITEM <= 7 ~ valores_reglas["rango1_7"],
            TRUE ~ valores_reglas["rango8_mas"]
          )
        ) %>%
        select(AFILIADO, FECHA, num_aut, descripcion, CODIGO, RECUENTO_ITEM, `CANT. NBU`, concepto, IMPORTE)

      # Modificar la columna IMPORTE para el CODIGO "0001" al valor ingresado por el usuario
      data_result_val$IMPORTE[data_result_val$CODIGO == "0001"] <- input$valor_acto_bioquimico

      # Transformar la columna FECHA a formato de fecha
      data_result_val$FECHA <- as.Date(data_result_val$FECHA, origin = "1899-12-30")

      # Mostrar la tabla resultante
      data_result(data_result_val)
    }
  })

  # Mostrar la tabla resultante
  output$result_table <- renderDT({
    datatable(
      data_result(),
      rownames = FALSE,
      extensions = 'Buttons',
      options = list(
        dom = 'Bfrtip',
        buttons = list('copy', 'csv', 'excel', 'pdf', 'print'),
        pageLength = nrow(data_result())  # Mostrar todas las entradas en una sola página
      )
    )
  })
}

# Ejecutar la aplicación Shiny
shinyApp(ui, server)
