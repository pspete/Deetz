# Contributing

All contributions, whether comments, code or otherwise are welcomed and appreciated.

## Deetz Issues

If you find an error in `Deetz`, or have a question relating to the module, [log an issue][new-issue].

## Pull Requests

When submitting a Pull Request, automated tasks run in [GitHub Actions][ci].

- Add an entry under `## Unreleased` in the [CHANGELOG](CHANGELOG.md); the PR check fails without one.
  - The entry sets the next version: a `### Added` section gives a minor release, anything else a patch.
  - There is no need to change the module version manually.
- The [`Pester`][pester-repo] tests for the module will run.
- [Code Coverage][code-coverage] metrics for the module will be determined.
- Once code is merged into the `main` branch, and all tests pass, the module is automatically published to the PowerShell Gallery and tagged as a Release on GitHub.
  - Code merged into the `vNext` branch is released as a GitHub prerelease.

## Contributing Code

- Fork the repo.
- Push your changes to your fork.
- Write [good commit messages][commit]
- If no related issue exists already, open a [New Issue][new-issue] describing the problem being fixed or feature.
- [Update documentation](#updating-documentation) for the command as required.
- Submit a pull request to the [`main` branch][main-branch]
  - Keep pull requests limited to a single issue
  - Discussion, or necessary changes may be needed before merging the contribution.
  - Link the pull request to the related issue

### PowerShell Styleguide

Use the standard _Verb_-_Noun_ convention, and only use approved verbs.

Public functions use external help (`# .ExternalHelp Deetz-help.xml` above `function`), generated from the [command help][command-help] markdown files.

[K&R (One True Brace Style variant)](https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81) preferred.

## Updating Documentation

Project documentation, examples and all content of the help files is able to be updated.

The command help content is generated from [these files][docs]

#### External Help File

[Command Help][command-help] Markdown files are the source of truth for the `Get-Help` content of the module.

Changes to these markdown files must be reflected in the `Get-Help` content.

The external help file is generated from the markdown by the build, using [pspete.Build][pspete-build]. To generate it locally:

```powershell
#From the repository root directory, run:
git clone --depth 1 --branch v1 https://github.com/pspete/pspete.Build build
./build/install.ps1
./build/help.ps1 -ModuleName Deetz
./build/test.ps1
```

[commit]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
[OTBS]: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/81
[new-issue]: https://github.com/pspete/Deetz/issues/new
[main-branch]: https://github.com/pspete/Deetz/tree/main
[ci]: https://github.com/pspete/Deetz/actions/workflows/ci.yml
[pspete-build]: https://github.com/pspete/pspete.Build
[pester-repo]: https://github.com/pester/Pester
[code-coverage]: https://codecov.io/gh/pspete/Deetz
[command-help]: https://github.com/pspete/Deetz/tree/main/docs/collections/_commands
