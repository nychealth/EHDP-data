# The Environment and Health Data Portal: Data

This repository serves data used by [the Environment and Health Data Portal](https://a816-dohbesp.nyc.gov/IndicatorPublic/beta/). 

Details on data files and definitions are available in Readme files in each folder:
- data-stories
- export-scripts
- geography
- indicators
- key-topics
- neighborhood-reports

## Contact us

You can comment on issues and we'll follow up as soon as we can. 

## Communications disclaimer

With regard to GitHub platform communications, staff from the New York City Department of Health & Mental Hygiene are authorized to answer specific questions of a technical nature with regard to this repository. Staff may not disclose private or sensitive data. 

## Feature branch merge strategy

Merging feature development branches into `production` is tricky in this repo: thousands of data files means thousands of potential merge conflicts. 

### My old strategies:

- Merge anyway, manually processing any non-data changes, and then accepting all incoming data changes, or staging the files with merge conflicts. **Downside**: makes VS Code unhappy, and depending on your settings you may be promped thousands of times for confirmation.
- Cherry pick the relevant commits. **Downside**: for feature branches with a long development history this could include dozens of commits scattered among many data exports, which would all have to be specified individually. 
- Checkout with `--patch` to merge only a specific file or folder, e.g. `git checkout --patch <feature-branch-name> export-scripts`. **Downside**: this requires reviewing changes in the terminal instead of VS Code's merge editor, which is much more user friendly.

### My new strategy: Merge into a new branch created from production

This will involve deleting all data files from a copy of feature branch and the new production merge branch.

1. Create a new "merge" production branch from `production`, e.g. `production-merge-2023-12-28`
2. On `production-merge-2023-12-28`, delete everything but READMEs and folders from `indicators`, `indicators/data`, `neighborhood-reports/data` and `neighborhood-reports/images`
3. Commit the changes
4. Create a new "merge" feature branch from the main feature branch, e.g. `feature-whatever` -> `feature-whatever-merge-2023-12-28`
5. On `feature-whatever-merge-2023-12-28`, delete everything but READMEs and folders from `indicators`, `indicators/data`, `neighborhood-reports/data`, `neighborhood-reports/metadata` and `neighborhood-reports/images`
6. Commit the changes
7. Merge `feature-whatever-merge-2023-12-28` into `production-merge-2023-12-28`
8. Run all data export scripts on `production-merge-2023-12-28`
9. Commit the changes
10. PR / merge `production-merge-2023-12-28` into `production`

**Notes:** 

- The production database has to be updated before you export the data, including data updates or migration, and new or modified views and stored procedures.
- Creating a merge copy of the feature branch enables us to use the main feature branch as the data branch in code on `EH-dataportal` without breaking anything.
- It feels dangerous to commit file deletions in a branch that will be merged into `production`, but it's actually safe. Because you're re-exporting the data on `production-merge-2023-12-28`, its [tip](https://git-scm.com/docs/gitglossary#def_branch) has the data files, and that's what will be merged into `production`.