# Releasing GemStack

Everything lives in one repository, `gemstack-rb/gemstack`. Each gem in
`gems/` is published from it to rubygems.org as a separate gem (DECISIONS
D-061). All gems share one version.

> ⚠️ **Public publication.** The GitHub repository is public, and a
> gem pushed to rubygems.org is public and permanent: a version can be yanked
> but never re-used, and it stays mirrored and cached. Before every release,
> make sure nothing sensitive is included — no `.env` files, keys, passwords or
> tokens, and no customer, prospect or personal data. If you're not 100 % sure,
> stop and ask whoever manages your infrastructure or security first.
>
> Quick check (must print nothing):
>
> ```bash
> git ls-files | grep -iE '(^|/)\.env($|\.[^e])|\.pem$|\.key$|(^|/)(secrets?|credentials?)(\.[a-z]+)?$|_secret$|\.sql$|\.csv$|\.log$'
> ```

## One-time setup

### GitHub (organization `gemstack-rb`)

A `GITHUB_TOKEN` environment variable overrides `gh` logins, so clear it in the
terminal you release from (only that terminal is affected):

```bash
unset GITHUB_TOKEN
gh auth login          # GitHub.com → HTTPS → browser, as an owner of gemstack-rb
gh auth setup-git      # lets `git push` over HTTPS use that login
gh auth status
```

Create the (public) repository and push:

```bash
gh repo create gemstack-rb/gemstack --public \
  --description "GemStack: a fast, modular Ruby API framework for Next.js"
git remote add origin https://github.com/gemstack-rb/gemstack.git
git push -u origin main
```

### rubygems.org

1. Create the account (the gems list `Shoaib Malik <gemstack26@gmail.com>` as
   author) and turn on multi-factor authentication for **UI and API** — the
   gemspecs require MFA for every push.
2. Sign in on the machine you release from:

   ```bash
   gem signin            # stores an API key in ~/.gem/credentials
   ```

   A key limited to the "Push rubygem" scope is enough.

The first push of each name registers it to your account; `script/release`
pushes all fourteen at once so no name is left unclaimed.

## Every release

```bash
bundle exec rake version:set[0.2.0]     # every gemspec + GemStack::VERSION
# add "## 0.2.0" to CHANGELOG.md (and gem CHANGELOGs if you keep per-gem notes)
bundle install
GEMSTACK_TEST_DATABASE_URL=postgres://… GEMSTACK_TEST_REDIS_URL=redis://… bundle exec rake
GEMSTACK_E2E_DATABASE_URL=postgres://… script/e2e
git commit -am "Release 0.2.0" && git push

script/release 0.2.0                    # tests, rake gems:check, then gem push ×14 (asks for MFA codes)
git push origin v0.2.0
```

`script/release` refuses to run unless you're on `main`, the tree is clean and
pushed, the version matches and the changelog has an entry. It pushes in
dependency order (`gemstack-core` first, `gemstack` last) and skips versions
already published, so if an MFA code expires or the network drops halfway,
just run it again.

## Check a release

In a clean environment:

```bash
GEM_HOME=$(mktemp -d) GEM_PATH= gem install gemstack
gemstack version
gemstack new try_gemstack && cd try_gemstack && gemstack doctor
```

`bundle exec rake gems:check` does the same with the locally built gems before
anything is pushed.

## Mistakes

- **A broken version:** `gem yank gemstack-http -v 0.2.0` removes it from
  installs, but the number can't be reused — release `0.2.1`.
- **A secret got published:** yanking doesn't remove copies that were already
  downloaded or mirrored. Rotate the secret immediately, then yank, and tell
  whoever manages your infrastructure or security.
