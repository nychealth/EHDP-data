###########################################################################################-
###########################################################################################-
##
## updating database with edits
##
###########################################################################################-
###########################################################################################-

# assumes that your git credentials have already been verified

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

base_branch <- "compiled-data-edits"

#-----------------------------------------------------------------------------------------#
# check for open PRs first
#-----------------------------------------------------------------------------------------#

pr_titles <-
    gh(
        "/repos/nycehs/BESP_EHDP_data_editor/pulls",
        .token = Sys.getenv("PAT_for_NYCEHS"),
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
            "https://github.com/nycehs/BESP_EHDP_data_editor/pulls"
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
    
    is_linux() {
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
        server = "DESKTOP-PU7DGC1",
        database = "BESP_EHDP_data",
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

file_dir <- path("data/compiled_edits/BESP_EHDP_data")

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
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # get required column names
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    if (table_name == "new_viz") {
        
        # if "table" is new_viz, get columns needed to create new viz
        
        table_colnames <-
            c(
                "visualization_id",
                "dataset_id",
                "visualization_type_id",
                "include"
            )
        
    } else if (table_name == "visualization_dataset_flags") {
        
        # if table is visualization_dataset_flags, get the updateable subset
        
        table_colnames <-
            c(
                "vizdat_id", 
                "tbl", 
                "map", 
                "trend", 
                "links", 
                "disp", 
                "nr"
            )
        
    } else {
        
        # get column names from database
        
        table_colnames <- EHDP_data %>% tbl(table_name) %>% head(0) %>% colnames()
        
    }
    
    
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # load data from JSON
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    
    # filter files based on table name
    
    files <- files_to_upload %>% str_subset(glue("{table_name}-"))
    
    # print some info
    
    cat("Files:\n")
    cat("", paste0("\n  +  ", files %>% path_file() %>% path_ext_remove(), collapse = ""), sep = " ")
    
    cat("\n\n- - - - - - - - - - - - - - - - - - - - - - - -\n")
    
    # now load
    
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
        select(any_of(table_colnames))
    
    # keep only column names present in updated data
    
    data_column_names <- table_colnames[table_colnames %in% names(table_data)]
    

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # run update
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

    if (table_name == "new_viz") {
        
        # get new rows for `visualization` table
        
        visualization <- 
            table_data %>% 
            filter(include == 1) %>% 
            select(temp_visualization_id = visualization_id, visualization_type_id) %>% 
            distinct(temp_visualization_id, .keep_all = TRUE)
        
        temp_visualization_ids <- unique(visualization$temp_visualization_id)
        
        # get new rows for `visualization_dataset` table
        
        visualization_dataset <- 
            table_data %>% 
            filter(include == 1) %>% 
            select(temp_visualization_id = visualization_id, dataset_id) %>% 
            distinct()
        
        # loop over new `visualization` rows
        
        for (j in 1:length(temp_visualization_ids)) {
            
            # insert into `visualization`
            
            new_visualization <-
                visualization %>% 
                filter(temp_visualization_id == !!temp_visualization_ids[j]) %>% 
                select(visualization_type_id)
            
            dbWriteTable(
                EHDP_data,
                name = "visualization",
                value = new_visualization,
                append = TRUE,
                overwrite = FALSE
            )
            
            # get auto-incremented visualization_id
            
            new_visualization_id <- 
                EHDP_data %>% 
                dbGetQuery("SELECT ident_current('dbo.visualization') AS visualization_id") %>% 
                pull(visualization_id) %>% 
                as.numeric()
            
            # add new auto-incremented visualization_id to new `visualization_dataset` rows
            
            new_visualization_dataset <- 
                visualization_dataset %>% 
                filter(temp_visualization_id == !!temp_visualization_ids[j]) %>% 
                mutate(visualization_id = !!new_visualization_id, show = TRUE) %>% 
                select(visualization_id, dataset_id, show)
            
            # insert into `visualization_dataset`
            
            dbWriteTable(
                EHDP_data,
                name = "visualization_dataset",
                value = new_visualization_dataset,
                append = TRUE,
                overwrite = FALSE
            )
            
            
        }
        
    
    } else if (table_name == "visualization_dataset_flags") {
        
        
        # construct where clause
        
        where <- paste0(table_name, ".", data_column_names[1],   " = temp.", data_column_names[1])
        
        # get distinct based on 1st column = identity column
        
        table_data <- 
            table_data %>%
            distinct(!!sym(table_colnames[1]), .keep_all = TRUE)
        
        
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
        
    } else if (table_name == "dataset") {
        
        
        # construct where clause
        
        where <- paste0(table_name, ".", data_column_names[1],   " = temp.", data_column_names[1])
        
        # get distinct based on 1st column = identity column
        
        table_data <- 
            table_data %>%
            distinct(!!sym(table_colnames[1]), .keep_all = TRUE)
        
        
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
        
        
        # run update
        
        result <- 
            EHDP_data %>%
            dbExecute(
                paste(
                    "UPDATE", table_name,
                    "SET dataset.publish = temp.publish",
                    "FROM", temp_name, "AS temp",
                    "WHERE", where
                )
            )
        
        # log result
        
        cat("\n ", result, " rows\n", sep = "")
        
    } else {
        
        
        # construct where clause
        
        where <- paste0(table_name, ".", data_column_names[1],   " = temp.", data_column_names[1])
        
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
