#compdef neomutt-accounts

_neomutt_accounts() {
  local accounts_dir="$HOME/.config/neomutt/accounts"
  local -a accounts
  accounts=(${accounts_dir}/*(N:t))
  _describe 'account' accounts
}

compdef _neomutt_accounts neomutt-accounts 