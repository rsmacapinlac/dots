---------------
----  Options  --
-----------------
--
options.timeout = 120
options.subscribe = true
options.create = true
options.expunge = true

------------------
----  Accounts  --
------------------

local password = get_imap_password("MACAPINLAC_IMAP_PASSWORD", ".ritchie@macapinlac.com")

account = IMAP {
    server = 'imap.gmail.com',
    username = 'ritchie@macapinlac.com',
    password = password,
    ssl = "tls1"
}

------------------
----  Rules     --
------------------

-- https://syshero.org/2016-06-19-imapfilter-cleaning-up-your-mailbox-and/
-- remove meeting invites older than 90 days
cal_delete_older  = 90
messages = account["[Gmail]/All Mail"]:contain_field("sender", "calendar-notification@google.com") * account["[Gmail]/All Mail"]:is_older(cal_delete_older)
messages:move_messages(account["[Gmail]/Trash"])

-- Homelab: Yukari
yukari = account.INBOX:contain_subject('[YUKARI] A new DSM update has been detected on yukari')
yukari:move_messages(account['zzz - Automation/Homelab - Notifications'])

yukari = account.INBOX:contain_subject('[YUKARI] Packages on yukari are out-of-date')
yukari:move_messages(account['zzz - Automation/Homelab - Notifications'])

-- Newsletters
newsletters = account.INBOX:contain_to('ritchie+newsletter@macapinlac.com') +
              account.INBOX:contain_to('ritchie+newsletters@macapinlac.com') +
              account.INBOX:contain_from('carl@carlpullein.com') +
              account.INBOX:contain_from('crew@morningbrew.com')

newsletters:move_messages(account['zzz - Automated/Newsletters'])

-- BC Hydro and Fortis
bchydro = account.INBOX:contain_from('notifications@bchydro.com')
bchydro:move_messages(account['zzz - 3236 East 6th/BC Hydro'])

fortis = account.INBOX:contain_from('gas.customerservice@fortisbc.com')
fortis:move_messages(account['zzz - Automation/Download attachments'])

-- TD Canada trust
td = account.INBOX:contain_from('noreply@td.com')
td:move_messages(account['zzz - 3236 East 6th/TD Canada Trust'])

ess_principal = account.INBOX:contain_from('principal@ess.vancouver.bc.ca') *
                account.INBOX:contain_bcc('ess_parents@ess.vancouver.bc.ca')
ess_principal:move_messages(account['ESS/School Announcements'])

ess_sports = account.INBOX:contain_from('douo@ess.vancouver.bc.ca')
ess_sports:move_messages(account['ESS/Sports'])

ess_grade6  = account.INBOX:contain_from('buan@ess.vancouver.bc.ca') *
              account.INBOX:contain_bcc('grade6_parents@ess.vancouver.bc.ca')
ess_grade6:move_messages(account['ESS/Classroom News/Grade 6 - Chyler'])

ess_grade7  = account.INBOX:contain_from('johnson@ess.vancouver.bc.ca') *
         --   account.INBOX:contain_subject('Grade 7 Newsletter') or 
              account.INBOX:contain_bcc('grade7_parents@ess.vancouver.bc.ca')
ess_grade7:move_messages(account['ESS/Classroom News/Grade 7 - Mackenzee'])

-- shopping / promotions
shopping = account.INBOX:contain_to('ritchie+promotions@macapinlac.com') +
           account.INBOX:contain_to('ritchie+promotion@macapinlac.com') +
           -- Ollie Quinn
           account.INBOX:contain_from('latest@email.oqspecs.com')

shopping:move_messages(account['zzz - Automated/Shopping'])

-- Village at Walker Lakes related
villagewl = account.INBOX:contain_from('Pagnihotri@kdmmgmt.ca')
villagewl:move_messages(account['zzz - Village at Walker Lakes/KDM Management'])

-- random banking stuff (sometimes important)
banking = account.INBOX:contain_from('NO_REPLY@communications.bpi.com.ph')
banking:move_messages(account['zzz - Automated/Banking'])

-- allowance emails
simplii = account.INBOX:contain_from('notify@payments.interac.ca') * (
            account.INBOX:contain_subject('INTERAC e-Transfer: Your money transfer to MACKENZEE CHARL MACAPINLAC was deposited.') + 
            account.INBOX:contain_subject('INTERAC e-Transfer: Your money transfer to CHYLER ROWAN C MACAPINLAC was deposited.')
          )
simplii:move_messages(account['Receipts and Invoices'])

-- Jobs!
jobs        = account.INBOX:contain_from('jobs-noreply@linkedin.com') +
              account.INBOX:contain_from('hello@creativeclass.co') +
              account.INBOX:contain_to('ritchie+jobs@macapinlac.com')
jobs:move_messages(account['zzz - Automated/Jobs'])


-- RitchiePlex
ritchieplex = account.INBOX:contain_from('ritchieplex@macapinlac.network')
ritchieplex:move_messages(account['zzz - Automated/RitchiePlex'])


-- Ugh, just delete it!
ugh         = account.INBOX:contain_from('e-service@acmsmail.china-airlines.com')
ugh:delete_messages()
