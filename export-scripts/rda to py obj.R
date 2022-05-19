
library(tidyverse)
library(reticulate)

load("export-scripts/conversion_data/NR_json_writer.rda")

py$report_level_1          <- r_to_py(report_level_1, convert = TRUE)
py$report_level_1_small    <- r_to_py(report_level_1_small, convert = TRUE)
py$report_level_2          <- r_to_py(report_level_2, convert = TRUE)
py$report_level_3          <- r_to_py(report_level_3, convert = TRUE)
py$report_level_3_0        <- r_to_py(report_level_3_0, convert = TRUE)
py$report_level_3_nested   <- r_to_py(report_level_3_nested, convert = TRUE)
py$report_level_23_nested  <- r_to_py(report_level_23_nested, convert = TRUE)
py$report_level_123_nested <- r_to_py(report_level_123_nested, convert = TRUE)
py$report_level_123_nested <- r_to_py(report_level_123_nested, convert = TRUE)

py_run_string(
    "
import pyodbc
import pandas as pd
import string
import re
    "
)

repl_python()
