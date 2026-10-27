# Held back

What step 6 of the `update` skill does when a package can't reach its latest version. Held back is a question to answer, not a result to report.

## Find the blocker

- Try the upgrade (`flutter pub upgrade --major-versions <pkg>`, `npm install <pkg>@latest`) and read the resolver's error: it names the package and the range that hold it.
- Or walk the tree: `flutter pub deps` (`dart pub deps`), `npm ls <pkg>`, `pnpm why <pkg>`, `yarn why <pkg>`.
- The blocker is usually a shared dependency: two packages need different majors of a third.

## Clear it

Try these in order; stop at the first that works.

**Move together.** Packages that share the blocking dependency go up in one command and one commit. Example: `win32` 5 → 6 moves `flutter_secure_storage`, `package_info_plus`, `share_plus` and `device_info_plus` together; none resolves alone.

**An unreleased upstream fix.** Open the blocker's repo (its `repository` or `homepage` in pub.dev, `repository` in `package.json`). When its main branch already allows the newer version but no release has it yet, override with a comment saying when to remove it:

```yaml
dependency_overrides:
  # Remove once <blocker> > <version> is released; its main already allows <pkg> <major>.
  <pkg>: ^<major>.0.0
```

npm: the same in `overrides` in `package.json` (pnpm: `pnpm.overrides`; Yarn 1: `resolutions`), with the reason in the pull request since JSON has no comments. Run the checks; an override that fails comes out again.

**The owner's own package.** A blocker that is a git or path dependency on one of the owner's repos: update it there. A sub-agent upgrades it on a branch and opens a pull request; merging and tagging it wait for the owner's go. Then point the project at the new tag and upgrade again.

**Nothing left.** The blocker has no fix upstream and isn't the owner's: it is truly blocked. Note the package, the blocker and its reason ("`<blocker>` still needs `<dep>` 5; no fix upstream yet").

## Report

The pull request lists every override with its removal condition, every owner package tagged, and every truly blocked package with its blocker. The user hears only the truly blocked ones, in plain words.
