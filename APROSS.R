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

# Interfaz de usuario
ui <- fluidPage(
  titlePanel("Valorización de Análisis por Afiliado"),
  fileInput("data_file", "Cargar archivo Excel", accept = c(".xlsx")),
  numericInput("rango1", "Valor para 1-6 análisis:", value = 153.5),
  numericInput("rango2", "Valor para 7-9 análisis:", value = 116),
  numericInput("rango3", "Valor para 10-13 análisis:", value = 97.72),
  numericInput("rango4", "Valor para 14-18 análisis:", value = 70),
  numericInput("rango5", "Valor para 19-23 análisis:", value = 50),
  numericInput("rango6", "Valor para 23-+ análisis:", value = 40),
  numericInput("valor_acto_bioquimico", "Valor del Acto Bioquímico:", value = 9),
  numericInput("valor_excepcion", "Índice Mediana Frecuencia:", value = 0.9),
  numericInput("valor_alta_frecuencia", "Índice para Alta Frecuencia:", value = 1.0),
  numericInput("input_valor_alta_complejidad", "Índice para Alta Complejidad:", value = 1.0),
  actionButton("generate_button", "GENERAR"),
  tabsetPanel(
    tabPanel("Detalle por Afiliado", DTOutput("result_table")),
    tabPanel("Resumen por Afiliado", DTOutput("resumen_table"))
  )
)

# Servidor
server <- function(input, output, session) {
  data <- reactiveVal(NULL)
  data_result <- reactiveVal(NULL)
  resumen_result <- reactiveVal(NULL)

  observeEvent(input$data_file, {
    data(transformar_nombres_columnas(read.xlsx(input$data_file$datapath)))
  })

  observeEvent(input$generate_button, {
    req(data())

    valores_reglas <- c(
      rango1 = input$rango1,
      rango2 = input$rango2,
      rango3 = input$rango3,
      rango4 = input$rango4,
      rango5 = input$rango5,
      rango6 = input$rango6
    )

    # Calcular total de análisis por afiliado (sin contar acto bioquímico)
    data_with_recuento <- data() %>%
      group_by(AFILIADO) %>%
      mutate(total_analisis = sum(CODIGO != "0001", na.rm = TRUE)) %>%
      ungroup()

    # Calcular el importe según el umbral del total de análisis del afiliado
    data_result_val <- data_with_recuento %>%
      mutate(
        IMPORTE = case_when(
          CODIGO == "0001" ~ input$valor_acto_bioquimico,
          total_analisis <= 6 ~ `CANT. NBU` * valores_reglas["rango1"],
          total_analisis <= 9 ~ `CANT. NBU` * valores_reglas["rango2"],
          total_analisis <= 13 ~ `CANT. NBU` * valores_reglas["rango3"],
          total_analisis <= 18 ~ `CANT. NBU` * valores_reglas["rango4"],
          total_analisis <= 23 ~ `CANT. NBU` * valores_reglas["rango5"],
          TRUE ~ `CANT. NBU` * valores_reglas["rango6"]
        )
      )

    # Aplicar excepciones al 90%
    codigos_excepcion <- c("0002", "0005", "0007", "0013", "0014", "0015", "0016", "0017",
                           "0018", "0022", "0023", "0025", "0027", "0028", "0029", "0030", "0031")
    data_result_val$IMPORTE[data_result_val$CODIGO %in% codigos_excepcion] <-
      data_result_val$IMPORTE[data_result_val$CODIGO %in% codigos_excepcion] * input$valor_excepcion

    # Convertir fecha si existe
    if ("FECHA" %in% names(data_result_val)) {
      data_result_val$FECHA <- as.Date(data_result_val$FECHA, origin = "1899-12-30")
    }

    # Guardar tabla detallada
    data_result(data_result_val)

    # Crear resumen por afiliado
    resumen <- data_result_val %>%
      group_by(AFILIADO) %>%
      summarise(
        TOTAL_ANALISIS = sum(CODIGO != "0001"),
        TOTAL_ACTO_BIOQ = sum(CODIGO == "0001"),
        IMPORTE_TOTAL = sum(IMPORTE, na.rm = TRUE)
      )
    resumen_result(resumen)
  })

  # Tabla detallada (expandible por afiliado)
  output$result_table <- renderDT({
    req(data_result())
    datatable(
      data_result(),
      rownames = FALSE,
      extensions = c('Buttons', 'RowGroup'),
      options = list(
        dom = 'Bfrtip',
        buttons = list('copy', 'csv', 'excel', 'pdf', 'print'),
        pageLength = 25,
        rowGroup = list(dataSrc = which(names(data_result()) == "AFILIADO"))
      )
    )
  })

  # Tabla resumen
  output$resumen_table <- renderDT({
    req(resumen_result())
    datatable(
      resumen_result(),
      rownames = FALSE,
      extensions = 'Buttons',
      options = list(
        dom = 'Bfrtip',
        buttons = list('copy', 'csv', 'excel', 'pdf', 'print'),
        pageLength = 25
      )
    )
  })
}

# Ejecutar la aplicación
shinyApp(ui, server)
