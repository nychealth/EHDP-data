
# This script should run on RStudio Server, from the folder "export-scripts"

# load reader, for better file reading
library(readr)
library(gert)
library(fs)

# make sure R is in the git repo directory
setwd(path(path_home(), "EHDP-data"))

# fetch info on all changes in remote repo
# system("git fetch origin")
git_fetch("origin")

# make sure you're on the production branch
# system("git checkout production")
git_branch_checkout("production")

# pull all changes on production
# system("git pull --all")
git_pull("origin")


