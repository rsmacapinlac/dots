----------------
--  Accounts  --
----------------
require "os"
package.path = package.path .. ';' .. os.getenv("HOME") .. '/.imapfilter/?.lua'

require("boogienet")
require("macapinlac")
