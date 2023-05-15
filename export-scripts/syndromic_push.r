# This script should run on RStudio Server, from the folder "export-scripts"

# load reader, for better file reading
library(readr)

# fetch info on all changes in remote repo
system("git fetch origin")

# make sure you're on the production branch
system("git checkout production")

# pull all changes on production
system("git pull --all")

# set long file path in object
heat_syndrome_dir <- "~/networkDrives/smb-share:server=sasshare01,share=sasshare/EHS/BESP/SecuredFolder/Syndromic/Heat_ED/EH data portal/live_data/EHDP-data/datafeatures/heatsyndrome"

# read the updated data
edheat_live <- read_csv(paste0(heat_syndrome_dir, "/edheat2023_live.csv"))

# restrict to the surveillance window
edheat_live2 <- edheat_live[edheat_live$END_DATE > start & edheat_live$END_DATE < end, ]

# save updated data to repo
write_csv(edheat_live2, "~/EHDP-data/key-topics/heat-syndrome/edheat2023_live.csv")

# add the file changes
system("git add --all")

# commit with message
system("git commit -m -a 'Regular auto-commit'")

# push changes to production
system("git push origin production")
