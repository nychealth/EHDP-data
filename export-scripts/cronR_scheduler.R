
library(fs)
library(cronR)
library(lubridate)

cron_add(
    command = cron_rscript(path(path_home(), "EHDP-data/export-scripts", "test_cronR.R")),
    frequency = paste(minute(now()) + 1, hour(now()), day(now()), month(now()), "*"),
    id = 'test_cronR',
    description = 'test_cronR',
    ask = FALSE
)
