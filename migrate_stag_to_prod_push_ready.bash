#!/bin/bash
sqlcmd -S SQLIT04A -d BESP_Indicator -E -C -Q "EXECUTE migrate_stag_to_prod_push_ready"