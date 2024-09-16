#!/bin/bash

###########################################################################################-
###########################################################################################-
##
## setting environemnt parameters
##
###########################################################################################-
###########################################################################################-

#-----------------------------------------------------------------------------------------#
# setup
#-----------------------------------------------------------------------------------------#

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# set server based on computer name
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

if [[ "$COMPUTERNAME" == "DESKTOP-PU7DGC1" ]]; then
  export server="DESKTOP-PU7DGC1"
else
  export server="SQLIT04A"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# make sure you're on the right branch
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

current_branch=$(git rev-parse --abbrev-ref HEAD)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# Choose database to use
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

if [[ -z "$data_env" ]]; then

  # if $data_env doesn't exist yet, ask about setting it
  echo "-------------------------------------------------------------"
  echo ">> 1: data_env = []"

  echo "-------------------------------------------------------------"
  read -p "staging [*s] or production [p]? -- " -n 1 data_env_input

  if [[ -z "$data_env" ]]; then
  
    echo "-------------------------------------------------------------"
    echo ">> 2: data_env = [], default to s"

  fi
  
  export data_env=${data_env_input:-"s"}  # default to staging if nothing entered


  if [[ "$data_env" == "s" ]] && [[ "$current_branch" != "staging" ]]; then

    # ask about switching

    echo "-------------------------------------------------------------"
    echo ">> 3: 'data_env = s', not on < staging > branch"

    echo "-------------------------------------------------------------"
    read -p "Switch to < staging >? Yes [y] / No [*n] -- " -n 1 switch
    printf "\n"

    # switch branch, or not

    if [[ "$switch" == "y" ]]; then

      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = y', switching to < staging > branch"

      git checkout staging
      git pull

    elif [[ "$switch" == "n" ]]; then

      # don't switch
      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = n', staying on < $current_branch > branch"

    else

      # don't switch
      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = []', staying on < $current_branch > branch"

    fi

  elif [[ "$data_env" == "p" ]] && [[ "$current_branch" != "production" ]]; then

    # ask about switching
    echo "-------------------------------------------------------------"
    echo ">> 3: 'data_env = p', not on < production > branch"

    echo "-------------------------------------------------------------"
    read -p "Switch to < production > ? Yes [y] / No [*n] -- " -n 1 switch
    printf "\n"

    # switch branch, or not

    if [[ "$switch" == "y" ]]; then

      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = y', switching to < production > branch"

      git checkout production
      git pull

    elif [[ "$switch" == "n" ]]; then

      # don't switch
      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = n', staying on < $current_branch > branch"

    else

      # don't switch
      echo "-------------------------------------------------------------"
      echo ">> 4: 'switch = []', staying on < $current_branch > branch"

    fi

  else
  
    # stay on this branch
    echo "-------------------------------------------------------------"
    echo ">> 3: on < $current_branch >"

  fi

else

  # if the $data_env does exist, ask about setting it
  echo "-------------------------------------------------------------"
  echo ">> 1: 'data_env' exists"

  # if the $data_env does exist, ask about changing it
  echo "-------------------------------------------------------------"
  read -p "'data_env = $data_env' ... Switch environment? Yes [y] / No [*n] -- " -n 1 switch
  printf "\n"

  # change environment by overwriting $data_env

  if [[ "$switch" == "y" ]]; then

    echo "-------------------------------------------------------------"
    echo ">> 2: switch 'data_env'"

    echo "-------------------------------------------------------------"
    read -p "staging [*s] or production [p]? -- " -n 1 data_env_input

    export data_env=${data_env_input:-"s"}  # default to staging if nothing entered

    if [[ "$data_env" == "s" ]] && [[ "$current_branch" != "staging" ]]; then

      echo "-------------------------------------------------------------"
      echo ">> 4: 'data_env = s', not on staging branch"

      echo "-------------------------------------------------------------"
      read -p "Switch to staging? Yes [y] / No [*n] -- " -n 1 switch
      # printf "\n"

      if [[ "$switch" == "y" ]]; then

        echo "-------------------------------------------------------------"
        echo ">> 5: switching to staging branch"

        git checkout staging
        git pull

      fi

    elif [[ "$data_env" == "p" ]] && [[ "$current_branch" != "production" ]]; then

      echo "-------------------------------------------------------------"
      echo ">> 4: 'data_env = p', not on < production > branch"

      echo "-------------------------------------------------------------"
      read -p "Switch to < production > ? Yes [y] / No [*n] -- " -n 1 switch
      printf "\n"

      if [[ "$switch" == "y" ]]; then

        echo "-------------------------------------------------------------"
        echo ">> 5: switching to < production > branch"

        git checkout production
        git pull

      elif [[ "$switch" == "n" ]]; then

        # don't switch
        echo "-------------------------------------------------------------"
        echo ">> 5: 'switch = n', staying on < $current_branch > branch"

      else
        # don't switch
        echo "-------------------------------------------------------------"
        echo ">> 5: 'switch = []', staying on < $current_branch > branch"

      fi

    else
      echo "-------------------------------------------------------------"
      echo ">> 4: staying on < $current_branch > branch"

    fi

  elif [[ "$switch" == "n" ]]; then

    # don't switch
    echo "-------------------------------------------------------------"
    echo ">> 5: 'switch = n', staying on < $current_branch > branch"

  else

    # don't switch
    echo "-------------------------------------------------------------"
    echo ">> 5: 'switch = []', staying on < $current_branch > branch"

  fi
fi


# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# save current branch as an environment variable
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

export current_branch=$current_branch

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #
# set site branch
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - #

# ask user

echo "-------------------------------------------------------------"
read -p "Specify site repo branch (default = production): " site_branch

# if no value, set to current branch

if [[ -z "$site_branch" ]]; then

    site_branch='production'
    
fi

# ste env for R

export site_branch=$site_branch


# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# #
# #                             ---- THIS IS THE END! ----
# #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
