###########################################################################################-
###########################################################################################-
##
## setting git credentials
##
###########################################################################################-
###########################################################################################-

#=========================================================================================#
# Setting up ----
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# Loading libraries
#-----------------------------------------------------------------------------------------#

library(glue)
library(purrr)
library(gert)
library(credentials)
library(gitcreds)
library(xfun)

#-----------------------------------------------------------------------------------------#
# checking for credentials
#-----------------------------------------------------------------------------------------#

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
    
    # print so you know what to enter
    
    # Sys.getenv("PAT_for_NYCEHS")
    
    git_credential_update(glue("https://{user_name}@github.com"))
    
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
