# neomutt

Default neomutt configuration: UI, colors, key mappings, and HTML handling.
It carries no accounts, so it is safe to use as a starting point.

## Files

| File | Contents |
| --- | --- |
| `neomuttrc` | Entry point — UI, sidebar, formats, threading, composition |
| `colors` | Catppuccin Mocha palette |
| `mappings` | Key bindings |
| `mailcap` | How attachments and HTML mail are rendered |

`neomuttrc` sources `colors` and `mappings`, and points `mailcap_path` at
`mailcap`. All four deploy to `~/.config/neomutt/` through `rcm`.

## Adding accounts

`neomuttrc` sources no account on purpose. An account names a person — real
name, addresses, GPG signing key — so accounts are not tracked in this public
repository. neomutt starts without them, reading the local spool.

Put one file per account in `~/.config/neomutt/accounts/`, then source the
default and bind the others. `neomuttrc` has a worked example in the comment
block at the end.

If you keep your accounts in a private companion repository, list it *before*
this one in `DOTFILES_DIRS`. `rcm` takes the first tree that provides a path,
so a private `neomuttrc` overrides this default rather than the other way
round. See the repository README, "Private Companion Repository".

## Sending mail

Account files are expected to set `sendmail` to an `msmtp` account. Passwords
should come from `pass` via `passwordeval` rather than being stored in any
config file.
