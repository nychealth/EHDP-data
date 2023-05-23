# This script should run on RStudio Server, from the folder "export-scripts"

# load reader, for better file reading
library(readr)

# fetch info on all changes in remote repo
# system("git fetch origin")
git_fetch("origin")

# make sure you're on the production branch
# system("git checkout production")
git_branch_checkout("production")

# pull all changes on production
# system("git pull --all")
git_pull("origin")

# set long file path in object
heat_syndrome_dir <- "~/networkDrives/smb-share:server=sasshare01,share=sasshare/EHS/BESP/SecuredFolder/Syndromic/Heat_ED/EH data portal/live_data/EHDP-data/datafeatures/heatsyndrome"

# read the updated data
edheat_live <- read_csv(paste0(heat_syndrome_dir, "/edheat2023_live.csv"))

#set surveillence window
start=as.Date("2023-04-30")
end=as.Date("2023-10-01")

# restrict to the surveillance window
edheat_live2 <- edheat_live[edheat_live$END_DATE > start & edheat_live$END_DATE < end, ]

# save updated data to repo
write_csv(edheat_live2, "~/EHDP-data/key-topics/heat-syndrome/edheat2023_live.csv")

# add all file changes
# system("git add .")
git_add("~/EHDP-data/key-topics/heat-syndrome/edheat2023_live.csv")

# commit with message
# system("git commit --all --message 'Regular auto-commit'")
git_commit_all("Regular auto-commit")

# push changes to production
# system("git push origin")
git_push("origin")
