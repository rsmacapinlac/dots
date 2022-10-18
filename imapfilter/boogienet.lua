---------------
----  Options  --
-----------------
--
options.timeout = 120
options.subscribe = true
options.create = true
options.expunge = true

-- Utility function to get IMAP password from file
function get_imap_password(file)
  local home = os.getenv("HOME")
  local file = home .. "/" .. file
  local str = io.open(file):read()
  return str;
end

------------------
----  Accounts  --
------------------

-- status, password = pipe_from('pass Email/rsmacapinlac@boogienet.com')
password = get_imap_password('.rsmacapinlac@boogienet.com') 
account = IMAP {
    server = 'rcentral503.webserversystems.com',
    username = 'rsmacapinlac@boogienet.com',
    password = password 
}

account.INBOX:check_status()

------------------
----  Rules     --
------------------

-- Hosting Alerts
alerts = account.INBOX:contain_from('wordpress@alifewithgusto.com') +
         account.INBOX:contain_from('wordpress@boogienet.com')

alerts:move_messages(account['zzz - Automated.Hosting Plugin Alerts'])


-- Move for Monthly N8N Automations
weekly = account.INBOX:contain_from('noreply@opensrs.email')

weekly:move_messages(account['zzz - Automations.MonthlyReport'])

-- Move for N8N Automations
weekly = account.INBOX:contain_from('support@boogienet.com') *
         account.INBOX:contain_subject('Weekly report for All Websites')

weekly:move_messages(account['zzz - Automations.Weekly'])

-- delete successful InfiniteWP message
infinitewp_success = account.INBOX:contain_from('gwen@boogienet.com') *
                     account.INBOX:contain_subject('InfiniteWP | Everything is up to date.')
infinitewp_success:delete_messages()

-- move this message into the automations folder for n8n
infinitewp_updates = account.INBOX:contain_from('gwen@boogienet.com') *
                     account.INBOX:contain_subject('InfiniteWP | New Updates Available.')
infinitewp_updates:move_messages(account['zzz - Automations.InfiniteWP-Updates'])


-- Ugh, just delete it!
ugh         = account.INBOX:contain_from('boogiene@rcentral503.webserversystems.com') *
              account.INBOX:contain_subject('Cron')
ugh:delete_messages()
