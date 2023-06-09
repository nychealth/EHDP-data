###########################################################################################-
###########################################################################################-
##
## updating database with edits
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

suppressWarnings(suppressMessages(library(tidyverse)))
suppressWarnings(suppressMessages(library(DBI)))
suppressWarnings(suppressMessages(library(dbplyr)))
suppressWarnings(suppressMessages(library(odbc)))
suppressWarnings(suppressMessages(library(rlang)))
suppressWarnings(suppressMessages(library(jsonlite)))
suppressWarnings(suppressMessages(library(fs)))
suppressWarnings(suppressMessages(library(glue)))
suppressWarnings(suppressMessages(library(gert)))
suppressWarnings(suppressMessages(library(gh)))
suppressWarnings(suppressMessages(library(credentials)))
suppressWarnings(suppressMessages(library(gitcreds)))
suppressWarnings(suppressMessages(library(xfun)))

#-----------------------------------------------------------------------------------------#
# millisecond timestamp, slightly modified from R.utils::currentTimeMillis
#-----------------------------------------------------------------------------------------#

options(scipen = 100)

now_ms <- function () {
    secs <- as.numeric(Sys.time())
    times <- unname(proc.time())
    time <- times[2]
    if (is.na(time))
        time <- times[3]
    (secs + time %% 1) * 10000
}

#-----------------------------------------------------------------------------------------#
# set base branch
#-----------------------------------------------------------------------------------------#

# base_branch <- "compiled-data-edits"
base_branch <- "feature-data-editor"

#-----------------------------------------------------------------------------------------#
# check for open PRs first
#-----------------------------------------------------------------------------------------#

pr_titles <-
    gh(
        "/repos/nychealth/EHDP-data/pulls",
        .token = Sys.getenv("token_for_everything"),
        state = "open"
    ) %>% 
    map_chr( ~ .x$title) %>% 
    keep( ~ .x %>% str_detect("working-data-edits"))

if (length(pr_titles) > 0) {
    
    stop(
        c(
            "Close these open PRs first!\n",
            "\n",
            paste0(" - ", pr_titles, "\n"),
            "\n",
            "https://github.com/nychealth/EHDP-data/pulls"
        ),
        call. = FALSE
    )
    
}

#-----------------------------------------------------------------------------------------#
# git branch and auth
#-----------------------------------------------------------------------------------------#

repo_status <- git_status()
repo_branch <- git_branch()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# deal with credentials
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

config <- git_config()
user_name <- config$value[config$name == "user.name"]

# run `gitcreds_get` without throwing an error

possibly_gitcreds_get <- possibly(gitcreds_get)

has_cred <- possibly_gitcreds_get(glue("https://{user_name}@github.com"))

if (is.null(has_cred)) {
    
    # if this is the RStudio server, set credential helper to "Store"
    
    if (is_linux()) {
        credential_helper_set("credential-store")
    }
    
    Sys.getenv("PAT_for_NYCEHS")

    git_credential_update(glue("https://{user_name}@github.com"))
    
}


if (repo_branch != base_branch) {
    
    # if there are any uncomitted changes, stash them
    
    if (nrow(repo_status) > 0) {
        
        git_stash_save(
            message = glue("{repo_branch} {now()}"),
            keep_index = FALSE,
            include_untracked = TRUE
        )
        
    }
    
    # fetch changes into `base_branch` before checking it out (might be unnecessary)
    
    git_fetch(refspec = glue("{base_branch}:{base_branch}"))
    
    # checkout `base_branch`
    
    git_branch_checkout(base_branch)
    
} else {
    
    # pull any changes
    
    git_pull()
    
}


#-----------------------------------------------------------------------------------------#
# Connecting to database
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get driver
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

odbc_driver <- 
    odbcListDrivers() %>% 
    pull(name) %>% 
    unique() %>% 
    str_subset("ODBC Driver") %>% 
    sort(decreasing = TRUE) %>% 
    head(1)

if (length(odbc_driver) == 0) odbc_driver <- "SQL Server"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# connect
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

EHDP_data <-
    dbConnect(
        drv = odbc::odbc(),
        driver = paste0("{", odbc_driver, "}"),
        # server = "DESKTOP-PU7DGC1",
        server = "SQLIT04A",
        database = "BESP_IndicatorAnalysis",
        trusted_connection = "yes",
        encoding = "latin1",
        trustservercertificate = "yes"
    )


#=========================================================================================#
# updating ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# importing
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getting file paths ----
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

file_dir <- path("data-editor/data/compiled_edits/BESP_IndicatorAnalysis")

files_to_upload <- dir_ls(file_dir)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# getting table names
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

table_names <- 
    files_to_upload %>% 
    path_file() %>% 
    path_ext_remove() %>% 
    str_replace("(\\w+)-\\w*", "\\1") %>% 
    unique()

# setting temp table names

ms_time <- format(now_ms())

temp_names <- glue("{table_names}_temp_{ms_time}")

print(temp_names)


#-----------------------------------------------------------------------------------------#
# updating each table ----
#-----------------------------------------------------------------------------------------#

for (i in 1:length(table_names)) {
    
    # set table name for loop
    
    table_name <- table_names[i]
    temp_name  <- temp_names[i]
    
    # print some info
    
    cat("\n===============================================\n")
    cat("\nTable: ")
    cat(table_name, "\n", sep = "")
    cat("\n- - - - - - - - - - - - - - - - - - - - - - - -\n")
    cat("\n")
    
    # get column names from table
    
    table_colnames <- EHDP_data %>% tbl(table_name) %>% head(0) %>% colnames()
    
    # if table is subtopic_indicators, get the updateable subset
    
    if (table_name %>% str_detect("subtopic_indicators")) {

        table_colnames <-
            c(
                "subtopic_indicator_id",
                "ban_summary_flag",
                "mapping",
                "trend_time_graph",
                "creator_id",
                "push_ready"
            )
        
    }
    
    # filter files based on table name
    
    files <- files_to_upload %>% str_subset(glue("{table_name}-"))
    
    # print some info
    
    cat("Files:\n")
    cat("", paste0("\n  +  ", files %>% path_file() %>% path_ext_remove(), collapse = ""), sep = " ")
    
    cat("\n\n- - - - - - - - - - - - - - - - - - - - - - - -\n")
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # load data from JSON
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    table_data <- 
        files %>% 
        map_dfr(
            ~ fromJSON(.x) %>% 
                as_tibble() %>% 
                type_convert(col_types = cols(.default = col_guess()), guess_integer = TRUE) %>% 

                # for debugging
                mutate(
                    datetime = as_datetime(timestamp/1000, tz = "America/New_York"),
                    filename = .x %>% path_file() %>% path_ext_remove()
                )
        ) %>% 
        arrange(-timestamp) %>% 
        select(any_of(c(table_colnames, "stage_flag"))) %>%
        
        # get distinct based on 1st column = identity column
        distinct(!!sym(table_colnames[1]), .keep_all = TRUE)
    
    # rename the stage flag
    
    if (table_name %>% str_detect("subtopic_indicators")) {
        
        table_data <- table_data %>% rename(creator_id = stage_flag)
        
    }
    
    # keep only column names in updated data
    
    data_column_names <- table_colnames[table_colnames %in% names(table_data)]
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # write to temp table
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    dbWriteTable(
        EHDP_data,
        name = temp_name,
        value = table_data,
        append = FALSE,
        temporary = FALSE,
        overwrite = TRUE
    )
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # build update code
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    # construct where clause
    
    where <- paste0(table_name, ".", data_column_names[1],   " = temp.", data_column_names[1])
    
    # run update
    
    if (table_name == "subtopic_indicators") {
        
        # update 1 column at a time, because SQL Server won't update columns from different tables/views together
        
        cat("\nColumn: \n\n")
        
        data_column_names[-1] %>% 
            
            walk( ~ { 
                
                # log column name
                
                cat(" ", .x, ":\t", sep = "")
                
                # construct set clause
                
                set <- paste0(table_name, ".", .x,  " = temp.", .x, collapse = ", ")
                
                # run update
                
                result <- 
                    EHDP_data %>%
                    dbExecute(
                        paste(
                            "UPDATE", table_name,
                            "SET", set,
                            "FROM", temp_name, "AS temp",
                            "WHERE", where
                        )
                    )
                
                # log result

                cat(" ", result, " rows\n", sep = "")
                
            })
        
    } else {
        
        # construct set clause
        
        set <- paste0(table_name, ".", data_column_names[-1],  " = temp.", data_column_names[-1], collapse = ", ")
        
        # run update
        
        result <- 
            EHDP_data %>%
            dbExecute(
                paste(
                    "UPDATE", table_name,
                    "SET", set,
                    "FROM", temp_name, "AS temp",
                    "WHERE", where
                )
            )
        
        # log result
        
        cat("\n ", result, " rows\n", sep = "")
        
    }
    
}

cat("\n===============================================\n")


#-----------------------------------------------------------------------------------------#
# clean up ----
#-----------------------------------------------------------------------------------------#

# check that the update succeeded before cleaning up?

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# delete temp tables
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cat("Dropping temp tables\n")

temp_names %>% walk( ~ dbExecute(EHDP_data, paste("DROP TABLE", .x)))

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# delete compiled tables
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cat("Deleting compiled edits\n")

files_to_upload %>% file_delete()

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# commit deletions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cat("Committing the deletions\n")
git_commit_all("removing compiled_edits")

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# push deletions
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

cat("Pushing the deletions\n")
git_push()

#-----------------------------------------------------------------------------------------#
# disconnect from database ----
#-----------------------------------------------------------------------------------------#

dbDisconnect(EHDP_data)

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
