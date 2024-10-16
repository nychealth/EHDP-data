# Feature branch merge strategy

Merging feature development branches into `production` is tricky in this repo: thousands of data files means thousands of potential merge conflicts. 

## My old strategies:

- Merge anyway, manually processing any non-data changes, and then accepting all incoming data changes, or staging the files with merge conflicts. **Downside**: makes VS Code unhappy, and depending on your settings you may be promped thousands of times for confirmation.
- Cherry pick the relevant commits. **Downside**: for feature branches with a long development history this could include dozens of commits scattered among many data exports, which would all have to be specified individually. 
- Checkout with `--patch` to merge only a specific file or folder, e.g. `git checkout --patch <feature-branch-name> export-scripts`. **Downside**: this requires reviewing changes in the terminal instead of VS Code's merge editor, which is much more user friendly.

## My new strategy: Merge into a new branch created from production

This will involve deleting all data files from a copy of feature branch and the new production merge branch.

1. Create a new "merge" production branch from `production`, e.g. `merge/2023-12-28/production`
2. On `merge/2023-12-28/production`, run `delete_data_files.[ps1/sh]` to delete everything but READMEs and folders from `indicators/data`, `indicators/metadata`, `neighborhood-reports/data/report`, `neighborhood-reports/data/viz`, `neighborhood-reports/metadata` and `neighborhood-reports/images`.
3. Commit the changes
4. Create a new "merge" feature branch from the main feature branch, e.g. `feature-whatever` -> `merge/2023-12-28/feature-whatever`
5. On `merge/2023-12-28/feature-whatever`, run `delete_data_files.[ps1/sh]`
6. Commit the changes
7. Merge `merge/2023-12-28/feature-whatever` into `merge/2023-12-28/production`
8. Run all data export scripts on `merge/2023-12-28/production`
9. Commit the changes
10. PR / merge `merge/2023-12-28/production` into `production`

**Notes:** 

- The production database has to be updated before you export the data, including data updates or migration, and new or modified views and stored procedures.
- Creating a merge copy of the feature branch enables us to use the main feature branch as the data branch in code on `EH-dataportal` without breaking anything.
- It feels dangerous to commit file deletions in a branch that will be merged into `production`, but it's actually safe. Because you're re-exporting the data on `merge/2023-12-28/production`, its [tip](https://git-scm.com/docs/gitglossary#def_branch) has the data files, and that's what will be merged into `production`.