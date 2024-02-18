library(shiny)
library(RSQLite)
library(DBI)

ui = fluidPage(
  fileInput("filein", "Choose file (sqlite)", multiple = FALSE, accept = c(".sqlite")),
  selectInput('fileopts','Opts:',c("NA")),
  selectInput('fileopts2','Opts:',c("NA")),
  selectInput('fileopts3','Opts:',c("NA"))
)

server = function(input, output, session) {

  #sqlitedb <- reactive({
  #  req(input$filein)
  #  dbConnect(dbDriver("SQLite"), gsub("\\\\","/",input$filein$datapath))
  #})

  #tables <- reactive({
  #  req(sqlitedb)
  #  dbListTables(sqlitedb) #dbReadTable(sqlitedb,tab) for models, runtimes etc
  #})

  observe({
    updateSelectInput(session,'fileopts',choices=c(input$filein))
  })
  observe({
    updateSelectInput(session,'fileopts2',choices=c(input$fileopts))
  })
  observe({
    req(input$filein)
    sqlitedb <- dbConnect(dbDriver("SQLite"), gsub("\\\\","/",input$filein$datapath))
    tables <- dbListTables(sqlitedb) #dbReadTable(sqlitedb,tab) for models, runtimes etc
    updateSelectInput(session,'fileopts3',choices=c(tables))
    dbDisconnect(sqlitedb)
    print("sqlitedb closed")
  })

  #reactive({
  #  req(sqlitedb)
  #  dbDisconnect(sqlitedb)
  #  print("sqlitedb closed")
  #})

}

runApp(shinyApp(ui = ui, server = server))
