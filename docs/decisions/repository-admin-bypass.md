# Repository admin bypass

The repository owner chose to retain the `always` bypass for the Repository
Admin role on the `Protect main` ruleset. The owner is the only holder of that
role and wants to retain the ability to override the rules deliberately.

The bypass allows the owner to proceed even when required checks are pending,
failing, or missing. Regular changes follow the protected pull request and squash
merge process with `CI`, `gitleaks`, and `Validate PR Title` passing on the current
revision.
