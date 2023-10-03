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

    Write-Host "-- N-1. no `$Env:data_env --"

    $Env:data_env = (Read-Host "*staging [s] or production [p]?").ToLower().Trim()[0]

    # if nothing entered, default to staging

    if (!$Env:data_env) {
        Write-Host "-- N-2. no `$Env:data_env, default to 's' --"
        $Env:data_env = "s"
    }

    if (($Env:data_env -eq "s") -and ($current_branch -ne "staging")) {

        # ask about switching

        Write-Host "-- N-3s. `$Env:data_env = 's', not on 'staging' branch --"

        $switch = (Read-Host "Switch to 'staging'? Yes [y] / *No [n]").ToLower().Trim()[0]

        # switch branch, or not

        if ($switch -eq "y") {

            Write-Host "-- N-4s-y. `$switch = 'y', switching to 'staging' branch --"

            git checkout staging
            git pull

        } elseif ($switch -eq "n") {

            # don't switch

            Write-Host "-- N-4s-n. `$switch = 'n', staying on '$current_branch' branch --"

        } else {

            # don't switch

            Write-Host "-- N-4s-_. no `$switch, staying on '$current_branch' branch --"

        }

        
    } elseif (($Env:data_env -eq "p") -and ($current_branch -ne "production")) {

        # ask about switching

        Write-Host "-- N-3p. `$Env:data_env = 'p', not on 'production' branch --"

        $switch = (Read-Host "Switch to 'production'? Yes [y] / *No [n]").ToLower().Trim()[0]

        # switch branch, or not

        if ($switch -eq "y") {

            Write-Host "-- N-4p-y. `$switch = 'y', switching to 'production' branch --"

            git checkout staging
            git pull

        } elseif ($switch -eq "n") {

            # don't switch

            Write-Host "-- N-4p-n. `$switch = 'n', staying on '$current_branch' branch --"

        } else {

            # don't switch

            Write-Host "-- N-4p-_. no `$switch, staying on '$current_branch' branch --"

        }
        

    } else {
        
        # stay on this branch

        Write-Host "-- 3. on '$current_branch' --"

    }


} else {

    # if the $Env:data_env does exist, ask about setting it

    Write-Host "-- Y-1 `$Env:data_env exists --"

    # if the $Env:data_env does exist, ask about chanaging it

    $switch = (Read-Host "`$Env:data_env = '$Env:data_env': Switch environment? Yes [y] / *No [n]").ToLower().Trim()[0]

    # change environment by overwriting $Env:data_env

    if ($switch -eq "y") {

        Write-Host "-- Y-2. switch `$Env:data_env --"

        $Env:data_env = (Read-Host "*staging [s] or production [p]?").ToLower().Trim()[0]

        # if nothing entered, default to staging

        if (!$Env:data_env) {
            Write-Host "-- Y-3. no `$Env:data_env, default to 's' --"
            $Env:data_env = "s"
        }


        if (($Env:data_env -eq "s") -and ($current_branch -ne "staging")) {

            Write-Host "-- Y-4s. `$Env:data_env = 's', not on staging branch --"

            $switch = (Read-Host "Switch to staging? Yes [y] / *No [n]").ToLower().Trim()[0]

            if ($switch -eq "y") {

                Write-Host "-- Y-5s. switching to staging branch --"

                git checkout staging
                git pull

            }

            
        } elseif (($Env:data_env -eq "p") -and ($current_branch -ne "production")) {

            Write-Host "-- Y-4p. `$Env:data_env = 'p', not on production branch --"

            $switch = (Read-Host "Switch to production? Yes [y] / *No [n]").ToLower().Trim()[0]

            if ($switch -eq "y") {

                Write-Host "-- Y-5p-y. switching to production branch --"

                git checkout production
                git pull

            } elseif ($switch -eq "n") {

                # don't switch

                Write-Host "-- Y-5p-n. `$switch = 'n', staying on '$current_branch' branch --"

            } else {

                # don't switch

                Write-Host "-- N-4p-_. no `$switch, staying on '$current_branch' branch --"

            }
            
        }

    } elseif ($switch -eq "n") {

        # don't switch

        Write-Host "-- Y-5p-n. `$switch = 'n', staying on '$current_branch' branch --"

    } else {

        # don't switch

        Write-Host "-- N-4p-_. no `$switch, staying on '$current_branch' branch --"

    }

}

