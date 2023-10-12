###########################################################################################-
###########################################################################################-
##
## Running all data export scripts
##
###########################################################################################-
###########################################################################################-

#-----------------------------------------------------------------------------------------#
# setup
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# get parent dir for absolute path
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

$base_dir = Get-Location

$Env:base_dir = $base_dir

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# set server based on computer name
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

if ($Env:COMPUTERNAME -eq "DESKTOP-PU7DGC1") {

    $Env:server = "DESKTOP-PU7DGC1"

} else {

    $Env:server = "SQLIT04A"

}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
    # make sure you're on the right branch
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

$current_branch = git branch --show-current

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Choose database to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

if (!$Env:data_env) {

    # if $Env:data_env doesn't exist yet, ask about setting it

    Write-Host "-------------------------------------------------------------"
    Write-Host ">> 1: `$Env:data_env = []"

    Write-Host "-------------------------------------------------------------"
    $Env:data_env = (Read-Host "staging [*s] or production [p]? ").ToLower().Trim()[0]

    # if nothing entered, default to staging

    if (!$Env:data_env) {

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 2: `$Env:data_env = [], default to s"
        $Env:data_env = "s"

    }

    if (($Env:data_env -eq "s") -and ($current_branch -ne "staging")) {

        # ask about switching

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 3: `$Env:data_env = s, not on < staging > branch"

        Write-Host "-------------------------------------------------------------"
        $switch = (Read-Host "Switch to < staging >? Yes [y] / No [*n] ").ToLower().Trim()[0]

        # switch branch, or not

        if ($switch -eq "y") {

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = y, switching to < staging > branch"

            git checkout staging
            git pull

        } elseif ($switch -eq "n") {

            # don't switch

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = n, staying on < $current_branch > branch"

        } else {

            # don't switch

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = [], staying on < $current_branch > branch"

        }

        
    } elseif (($Env:data_env -eq "p") -and ($current_branch -ne "production")) {

        # ask about switching

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 3: `$Env:data_env = p, not on < production > branch"

        Write-Host "-------------------------------------------------------------"
        $switch = (Read-Host "Switch to < production > ? Yes [y] / No [*n] ").ToLower().Trim()[0]

        # switch branch, or not

        if ($switch -eq "y") {

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = y, switching to < production > branch"

            git checkout staging
            git pull

        } elseif ($switch -eq "n") {

            # don't switch

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = n, staying on < $current_branch > branch"

        } else {

            # don't switch

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$switch = [], staying on < $current_branch > branch"

        }
        

    } else {
        
        # stay on this branch

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 3: on < $current_branch >"

    }


} else {

    # if the $Env:data_env does exist, ask about setting it

    Write-Host "-------------------------------------------------------------"
    Write-Host ">> 1: '`$Env:data_env' exists"

    # if the $Env:data_env does exist, ask about chanaging it

    Write-Host "-------------------------------------------------------------"
    $switch = (Read-Host "`$Env:data_env = $Env:data_env ... Switch environment? Yes [y] / No [*n] ").ToLower().Trim()[0]

    # change environment by overwriting $Env:data_env

    if ($switch -eq "y") {

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 2: switch '`$Env:data_env'"

        Write-Host "-------------------------------------------------------------"
        $Env:data_env = (Read-Host "staging [*s] or production [p]? ").ToLower().Trim()[0]

        # if nothing entered, default to staging

        if (!$Env:data_env) {
            
            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 3: `$Env:data_env = [], default to s"
            $Env:data_env = "s"
        
        }


        if (($Env:data_env -eq "s") -and ($current_branch -ne "staging")) {

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$Env:data_env = s, not on staging branch"

            Write-Host "-------------------------------------------------------------"
            $switch = (Read-Host "Switch to staging? Yes [y] / No [*n] ").ToLower().Trim()[0]

            if ($switch -eq "y") {

                Write-Host "-------------------------------------------------------------"
                Write-Host ">> 5: switching to staging branch"

                git checkout staging
                git pull

            }

            
        } elseif (($Env:data_env -eq "p") -and ($current_branch -ne "production")) {

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: `$Env:data_env = p, not on < production > branch"

            Write-Host "-------------------------------------------------------------"
            $switch = (Read-Host "Switch to < production > ? Yes [y] / No [*n] ").ToLower().Trim()[0]

            if ($switch -eq "y") {

                Write-Host "-------------------------------------------------------------"
                Write-Host ">> 5: switching to < production > branch"

                git checkout production
                git pull

            } elseif ($switch -eq "n") {

                # don't switch

                Write-Host "-------------------------------------------------------------"
                Write-Host ">> 5: `$switch = n, staying on < $current_branch > branch"

            } else {

                # don't switch

                Write-Host "-------------------------------------------------------------"
                Write-Host ">> 5: `$switch = [], staying on < $current_branch > branch"

            }
            
        } else {

            Write-Host "-------------------------------------------------------------"
            Write-Host ">> 4: staying on < $current_branch > branch"

        }

    } elseif ($switch -eq "n") {

        # don't switch

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 5: `$switch = n, staying on < $current_branch > branch"

    } else {

        # don't switch

        Write-Host "-------------------------------------------------------------"
        Write-Host ">> 5: `$switch = [], staying on < $current_branch > branch"

    }

}

Write-Host "-------------------------------------------------------------"


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Tell conda which environment to load
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# conda activate EHDP-data

#=========================================================================================#
# R
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# EXP data
#-----------------------------------------------------------------------------------------#

Write-Output ">>> EXP_data_json"

Rscript $base_dir\export-scripts\EXP_data_json.R

#-----------------------------------------------------------------------------------------#
# EXP metadata
#-----------------------------------------------------------------------------------------#

Write-Output ">>> EXP_metadata_json"

Rscript $base_dir\export-scripts\EXP_metadata_json.R

#-----------------------------------------------------------------------------------------#
# EXP comparisons
#-----------------------------------------------------------------------------------------#

Write-Output ">>> EXP_comparisons_json"

Rscript $base_dir\export-scripts\EXP_comparisons_json.R

#-----------------------------------------------------------------------------------------#
# EXP TimePeriods
#-----------------------------------------------------------------------------------------#

Write-Output ">>> EXP_TimePeriods_json"

Rscript $base_dir\export-scripts\EXP_TimePeriods_json.R

#-----------------------------------------------------------------------------------------#
# NR viz data (for VegaLite)
#-----------------------------------------------------------------------------------------#

Write-Output ">>> NR_data_csv"

Rscript $base_dir\export-scripts\NR_data_csv.R

#-----------------------------------------------------------------------------------------#
# NR JSON data (for report)
#-----------------------------------------------------------------------------------------#

Write-Output ">>> NR_report_json"

Rscript $base_dir\export-scripts\NR_report_json.R

#-----------------------------------------------------------------------------------------#
# GeoLookup
#-----------------------------------------------------------------------------------------#

# Write-Output ">>> EXP_GeoLookup_csv"

# Rscript $base_dir\export-scripts\EXP_GeoLookup_csv.R


#=========================================================================================#
# Python
#=========================================================================================#

#-----------------------------------------------------------------------------------------#
# EXP metadata
#-----------------------------------------------------------------------------------------#

# Write-Output ">>> EXP_metadata_json"

# python $base_dir\export-scripts\EXP_metadata_json.py

#-----------------------------------------------------------------------------------------#
# NR spark bars
#-----------------------------------------------------------------------------------------#

# Write-Output ">>> NR_sparkbars"

# python $base_dir\export-scripts\NR_sparkbars.py


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
