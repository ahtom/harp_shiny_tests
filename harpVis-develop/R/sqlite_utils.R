### DEFINE USEFUL FUNCTIONS FOR SQLite
### dbwrite, dbquery, dbclear

### a more or less robust & fast data-base connection (?)
### In fact, really robust is impossible!
### 2 sessions of RSQLite on the same computer
### are not well isolated (not thread safe)
### so e.g. dbGetException doesn't give the correct messages???
### dbWriteTable and dbReadTable should be avoided!!!

### little convenience functions:

# Note - these fuctions are not exported. #AD: WHY NOT?

# @param dbfile Name of an SQLite file. If it does not exist, it is created.
# @param lock If TRUE, file locking is used.
#   Set to FALSE on network file systems like NFS and lustre.
# @value A data base connection
# @export
dbopen <- function(dbfile, lock) {
  if (utils::packageVersion("DBI") < "0.5") stop("Unfortunately, HARP will only
function correctly with package DBI version 0.5 or higher.")
  if (missing(lock)) {
    if (exists(".SQLiteLocking")) lock <- get(".SQLiteLocking")
    else lock <- TRUE
  }
  if (lock)  DBI::dbConnect(RSQLite::SQLite(), dbname=dbfile)
  else {
    DBI::dbConnect(RSQLite::SQLite(), dbname=dbfile, vfs="unix-none")  # for Lustre, NFS
  }
  ### WARNING: this turns off file locking completely!
}

dbclear <- function(db) {
  # in recent RSQLite, some strangeness may happen!
  # dbListResults is deprecated, so we can't do anything here!

#  if (packageVersion('RSQLite')<'1.0.0') {for(i in dbListResults(db)) dbClearResult(i)}
#  else for (i in dbListResults(db)) {if (dbIsValid(i)) dbClearResult(i)}
  cat("warning: you shouldn't call dbclear anymore.")
}

dbclose <- function(db) {
  #  bclear(db)
  invisible(DBI::dbDisconnect(db))
}

### add a new column to an existing table
db.add.columns <- function(db, table, colnames, quiet=FALSE){
  for (col in colnames){
    if (!quiet) cat("ADDING NEW COLUMN",col,"TO TABLE",table,"\n")
    sql_add <- paste("ALTER TABLE",table,"ADD",col,"REAL DEFAULT NULL")
    dbquery(db, sql_add)
  }
}

#######################################################################
### Robust dbwrite: write a full data.frame to an existing table    ###
###                 wait for file locks to avoid data corruption    ###
###                 safe for multiple processes accessing same file ###
#######################################################################

dbwrite <- function(conn, table, mydata, rounding=NULL, maxtry=20, sleep=5, show_query = FALSE){
  tnames <- DBI::dbListFields(conn, table)
  if (length(setdiff(tolower(names(mydata)), tolower(tnames))) > 0) {
    cat("ERROR: The new data contains fields that do not exist in the data base table!\n",
      "Consider re-creating SQLite file.\n")
    stop("Can not write data.")
  }

  SQL <- paste0("REPLACE into ",table," (",paste(names(mydata),collapse=","),") ",
    " values ",
    "(:", paste(names(mydata),collapse=",:"),")")

  if (!is.null(rounding)) {
    # notice that we include the "," in the substitution string to avoid partial fit
    for (f in intersect(names(rounding), names(mydata))) {
      sub(paste0(":",f,",") ,sprintf("round(:%s, %i),",f, rounding[[f]]), sql_write)
    }
  }

  if (utils::packageVersion('DBI') < '0.3.0') {
    dbBegin <- get("dbBeginTransaction", envir = asNamespace("DBI"))
  } else if (utils::packageVersion("RSQLite") < "1.0.0") {
    stop("RSQLite version is inconsistent with DBI. Consider upgrading.")
  }
  DBI::dbBegin(conn)  ### this is OK: doesn't require a lock

  prepOK <- FALSE
  count <- 1
  if (show_query) message("sending query: ", sql_write)
  while (!prepOK & count<=maxtry){

    tryOK1 <- tryCatch(DBI::dbSendQuery(conn, SQL, params=mydata),
      error=function(e) {print(e);return(e)}) ### this needs RESERVED lock

    if (inherits(tryOK1,"error")) {
      print(paste("FAILURE dbSendQuery",count,"/",maxtry))
      print(tryOK1$message)

      Sys.sleep(sleep)
      count <- count + 1
      next
    }
    else {
      prepOK <- TRUE
    }
  }
  if (!prepOK) {
    DBI::dbRollback(conn)
    stop("FATAL DBFAILURE: Unable to acquire lock.")
  }


  ### second stage (commit) will fail if another process is accessing the db (even just for reading)

  commitOK <- FALSE
  count <- 1
  while (!commitOK & count<=maxtry){
    DBI::dbClearResult(tryOK1)
    tryOK2 <- tryCatch(DBI::dbCommit(conn),
      error=function(e) {print(e);return(e)})  ### commit needs an EXCLUSIVE lock

    if (inherits(tryOK2,"error")) {
      print(paste("FAILURE commit",count,"/",maxtry))
      print(tryOK2$message)

      Sys.sleep(sleep)
      count <- count + 1
      next
    }
    else {
      commitOK <- TRUE
    }
  }
  if (!commitOK) {
    DBI::dbRollback(conn)
    DBI::dbClearResult(tryOK1)
    stop("FATAL DBFAILURE: Unable to commit.")
  } else {
    return(TRUE)
  }
}

######################################################
### Robust dbread: submit SQL to an existing table ###
######################################################
# dbGetResult combines send and fetch : hard to know where it went wrong... avoid
# it seems that the SendQuery doesn't require a lock, and doesn't impose any either.
# but once you "fetch" part of the result, database has a SHARED lock, so writing is not possible.
# if fetch is locked (other process is writing), dbGetExceptions doesn't give the error!
# so we use a different method!
dbquery <- function(conn, sql, maxtry=20, sleep=5){
  sendOK <- FALSE
  count <- 1
  while (!sendOK & count<=maxtry){
    result <- tryCatch(DBI::dbSendQuery(conn, sql),
      error=function(e) {print(e); return(e)})
    if (inherits(result,"error")) {
      print(paste("FAILURE dbSendQuery",count,"/",maxtry))
      print(result$message)

      Sys.sleep(sleep)
      count <- count + 1
      next
    }
    else {
      sendOK <- TRUE
    }
  }
  if (!sendOK) stop("FATAL DBFAILURE: Unable to query database.")

  #-- if the sql statement doesn't return data (not a select), there is nothing more to do:
  # Note $completed has changed to $has.completed in newer versions of DBI
  lCompleted <- DBI::dbGetInfo(result)$has.completed
  if (is.null(lCompleted)) lCompleted <- DBI::dbGetInfo(result)$completed
  if (is.null(lCompleted)) {
    cat("Problem with dbGetInfo result\n")
    print(DBI::dbGetInfo(result))
    stop("ABORTING!")
  }
  if (lCompleted) {
    # do I have to clear the result even if it is completed? YES!
    DBI::dbClearResult(result)
    return(TRUE)
  }

  # not yet completed: so we are expecting a return result
  fetchOK <- FALSE
  count <- 1
  while (!fetchOK & count<=maxtry){
    if (utils::packageVersion('DBI')<'0.3.0') dbFetch <- get("fetch", envir = asNamespace("DBI"))
    data <- tryCatch(DBI::dbFetch(result,n=-1),
      error=function(e) {print(e);return(e)})
    if (inherits(data,"error")) {
      print(paste("FAILURE dbFetch",count,"/",maxtry))
      print(data$message)

      Sys.sleep(sleep)
      count <- count + 1
      next
    }
    else {
      fetchOK <- TRUE
    }
  }
  # do I have to clear the result after a fetch? YES!
  DBI::dbClearResult(result)
  if (!fetchOK) stop("FATAL DBFAILURE: Unable to fetch from database.")
  return(data)
}

#############################
# Create a new table in an SQLite data base
#
# @param db A database connection
# @param name A name for the table. If it already exists, nothing happens.
# @param a data.frame. Only column names and type are used. Alternatively, it
#    can also be a named vector of date types.
# @param primary Primary keys
# @export
create_table <- function(db, name, data, primary=NULL, show_query = FALSE) {
  if (DBI::dbExistsTable(db, name)) {
## TODO: check fields are the same!!!
    return(NULL)
  }
  # NOTE: we a "POSIXct" type will be stored as "REAL"
  # for "switch" to work OK, we need a single element, so class()[1] is chosen
  if (is.data.frame(data)) {
    types <- vapply(seq_len(dim(data)[2]), function(x) switch(class(data[[x]])[1],
                                             "integer"="INTEGER",
                                             "numeric"="REAL",
                                             "character"="CHARACTER",
                                             "REAL"), FUN.VALUE="a")
  } else {
    types <- data
  }

  if ( is.null(primary) ) {
    sql_create <- sprintf("CREATE TABLE %s ( %s )",
                           name,
                           paste(names(data), types, collapse=","))
  } else {
    sql_create <- sprintf("CREATE TABLE %s ( %s , PRIMARY KEY(%s))",
                           name,
                           paste(names(data), types, collapse=","),
                           paste(primary, collapse=","))
  }
  if (show_query) message("Creation query: ", sql_create)
  dbquery(db, sql_create)
  invisible(sql_create)
}

cleanup_table <- function(db, tabname, where.list, show_query = FALSE) {
  # character values must be wrapped with single quotes in the SQL command!
  where.list <- lapply(where.list,
                       function(x) if (is.character(x)) paste0("'",x,"'")
                                   else x)
  wlist <- vapply(names(where.list), FUN.VALUE="a",
                  FUN=function(cc) sprintf("%s=%s",cc,where.list[[cc]]))
  sql_cleanup <- sprintf("DELETE FROM %s WHERE %s",
                         tabname, paste(wlist, collapse=" AND "))
  if (show_query) message("Cleanup query: ", sql_cleanup)
  dbquery(db, sql_cleanup)
  invisible(sql_cleanup)
}

################################################################
# Combine clean and write in a single transaction.
# Takes checks from dbwrite to deal with file locking etc.
################################################################

db_clean_and_write <- function(
  db_conn,
  db_table,
  df,
  index_cols,
  index_constraint = c("none", "unique"),
  rounding         = NULL,
  maxtry           = 20,
  sleep            = 5
) {

  table_cols <- DBI::dbListFields(db_conn, db_table)

  # Allow new style harp column names to be mixed with
  # old style column names

  bad_cols <- setdiff(tolower(colnames(df)), tolower(table_cols))
  if (is.element("fcst_dttm", bad_cols)) {
    colnames(df)[colnames(df) == "fcst_dttm"] <- "fcdate"
    index_cols[index_cols == "fcst_dttm"]     <- "fcdate"
  }
  if (is.element("valid_dttm", bad_cols)) {
    colnames(df)[colnames(df) == "valid_dttm"] <- "validdate"
    index_cols[index_cols == "valid_dttm"]     <- "validdate"
  }

  if (is.element("lead_time", bad_cols)) {
    colnames(df)[colnames(df) == "lead_time"] <- "leadtime"
    index_cols[index_cols == "lead_time"]     <- "leadtime"
  }
  bad_cols <- setdiff(tolower(colnames(df)), tolower(table_cols))

  if (length(bad_cols) > 0) {
    stop(
      paste(
        "The data to be written contain columns that do not exist in the database table.",
        "\nOffending column names: ", paste(bad_cols, collapse = ", "),
        "\nConsider recreating SQLite file.\n"
      ), call. = FALSE
    )
  }

  if (!all(index_cols %in% colnames(df))) {
    stop("'index_cols' must be column names in 'df'", call. = FALSE)
  }

  where_list <- purrr::map(index_cols, ~ unique(df[[.x]])) %>%
    purrr::set_names(index_cols)

  SQL_delete <- paste("DELETE FROM", db_table, generate_where(where_list))

  SQL_insert <- paste0(
    "INSERT into ", db_table, " (", paste(colnames(df), collapse = ","), ") ",
    " values (:", paste(colnames(df), collapse = ",:"), ")"
  )

  if (!is.null(rounding)) {
    for (f in intersect(names(rounding), names(df))) {
      sub(paste0(":", f, ","), sprintf("round(:%s, %i),", f, rounding[[f]]), SQL_insert)
    }
  }

  index_name <- paste("index", paste(index_cols, collapse = "_"), sep = "_")
  index_spec <- paste0(db_table, "(", paste(index_cols, collapse = ","), ")")

  transaction_OK <- tryCatch(
    DBI::dbWithTransaction(db_conn, {

      clean_OK <- FALSE
      count    <- 1

      while (!clean_OK & count <= maxtry) {

        results_set_clean <- tryCatch(
          DBI::dbSendStatement(db_conn, SQL_delete),
          error = function(err) err
        )


        if (inherits(results_set_clean, "error" )) {
          print(paste("FAILURE dbSendStatement:", count, "/" , maxtry))
          print(results_set_clean$message)
          Sys.sleep(sleep)
          count <- count + 1
        } else {
          clean_OK <- TRUE
        }

      }

      if (!clean_OK) {
        DBI::dbBreak()
      } else {
        DBI::dbClearResult(results_set_clean)
      }

      insert_OK <- FALSE
      count     <- 1

      while (!insert_OK & count <= maxtry) {

        results_set_insert <- tryCatch(
          DBI::dbSendStatement(db_conn, SQL_insert, params = df),
          error = function(err) err
        )


        if (inherits(results_set_insert, "error" )) {
          print(paste("FAILURE dbSendStatement:", count, "/" , maxtry))
          print(results_set_insert$message)
          Sys.sleep(sleep)
          count <- count + 1
        } else {
          insert_OK <- TRUE
        }

      }

      if (!insert_OK) {
        DBI::dbBreak()
      } else {
        DBI::dbClearResult(results_set_insert)
      }

    }),
    error = function(err) err
  )

  if (inherits(transaction_OK, "error") | is.null(transaction_OK)) {
    stop("Unable to to write to database file.\n", transaction_OK$message, call. = FALSE)
  }

  index_constraint <- match.arg(index_constraint)
  if (index_constraint == "none") index_constraint <- ""

  SQL_add_index <- paste(
    "CREATE",
    index_constraint,
    "INDEX IF NOT EXISTS",
    index_name,
    "ON",
    index_spec
  )

  dbquery(db_conn, SQL_add_index)
}


###############################################################
# Generate a WHERE sql statement from a list
###############################################################
generate_where <- function(where_list) {
  paste_query <- function(x, y) {
    if (is.character(y)) {
      paste0(x, " IN ('", paste(y, collapse = "','"), "')")
    } else {
      paste0(x, " IN (", paste(y, collapse = ","), ")")
    }
  }
  paste(
    "WHERE",
    paste(
      purrr::map2_chr(
        names(where_list),
        where_list,
        paste_query
      ),
      collapse = " AND "
    )
  )
}
