# Contributing

## Branch Model

The `main` branch is the integration branch for the repository.

Use short-lived branches per task, not permanent folder-only branches.

## Expected Workflow

1. Sync `main`.
2. Create a new branch from `main`.
3. Make focused changes for one task.
4. Commit with a clear message.
5. Push the branch.
6. Open a pull request into `main`.

Pull requests in this repository use the template in `.github/PULL_REQUEST_TEMPLATE.md`.

## Example

```powershell
git checkout main
git pull origin main
git checkout -b feat/assignment-2-readme-update
```

After making changes:

```powershell
git add "Assignment 2"
git commit -m "docs(assignment-2): update README"
git push -u origin feat/assignment-2-readme-update
```
