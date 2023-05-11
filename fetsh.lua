--[[
  dependencies:
    - "luv"     # As "uv". Built-in to Luvit.
  description: "A simple script using luv to display system info."
  license: "MIT"
  author:
    name: "NekOware"
  github: "https://github.com/NekOware/Luvit-Scripts/blob/main/fetsh.lua"
--]]

------------------------------------------------------------------------
-----[=[ Below are the cool variables you're allowed to change. ]=]-----

-- Use KiB/MiB/etc for human readable memory sizes.
-- FYI: `1KB == 1000B` and `1KiB == 1024B`
-- true  : Use 1024 as the step to the next size letter. (B<KiB<MiB<GiB<TiB<PiB<EiB<ZiB<YiB)
-- false : Use 1000 as the step to the next size letter. (B< KB< MB< GB< TB< PB< EB< ZB< YB)
local _USE_I_BYTES = false

-- Hehe, output go brrr
-- Should be self explanatory, but if not then prepare for your console to be flooded.
local _VERBOSE = false

-- Disables the 2.5 second sleep after changing the process title
--   and before the script collects the system info to be displayed. 
local _DISABLE_EXTRA_WAIT = false

-----[=[ Above are the cool variables you're allowed to change. ]=]-----
------------------------------------------------------------------------

--#region Utility functions

local _size_letters = { '', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' }
function byteSize(bytes, ibit)
  ibit = (ibit==nil) or (ibit==true)
  local size = 1
  for i = 1, 8 do
    local div = bytes / (ibit and 1024 or 1000)
    if (div - (div%1)) == 0 then
      break
    else
      bytes = div
      size = size+1
    end
  end
  return string.format('%.0'..(size==1 and''or'2')..'f%s%sB', bytes, _size_letters[size], (ibit and size>1 and'i'or'') )
end

function calcPercent(orig, targ)
  local prc = (targ/orig)*100
  return ('%.02f%%'):format(prc)
end

local _esc_chars = {
  ['\a']='\\a', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t', ['\v']='\\v', ['\\']='\\\\'
}
for i=0  ,31  do local c=string.char(i)_esc_chars[c]=(_esc_chars[c]or('\\%03i'):format(i))end
for i=127,255 do local c=string.char(i)_esc_chars[c]=(_esc_chars[c]or('\\%03i'):format(i))end
function escapeStr(str, quot)
  if type(str)~='string'then return nil end
  quot = (quot==nil)or(quot==true)
  local qchar
  if quot then
    local m_sq, m_dq = str:match("'"), str:match('"')
    if m_sq and not m_dq then qchar='"'else qchar="'"end
  end
  if qchar then _esc_chars[qchar]=('\\'..qchar)end
  local ret = str:gsub('.',_esc_chars)
  ret = ( (qchar or '') .. ret .. (qchar or '') )
  if qchar then _esc_chars[qchar]=nil end
  return ret
end

function pad(str, num, chr)
  if type(str)~='string'then return nil end
  chr = (type(chr)=='string'and chr:sub(1,1)or' ')
  num = (tonumber(num)or 0)
  local neg = num<0
  if neg then num=num*-1 end
  num = math.floor(num)
  if num == 0 then return str end
  local pad = (chr):rep(num):sub(#str+1)
  if neg then str=str..pad else str=pad..str end
  return str
end

--#endregion

local uv = require('uv')

local function p_concat(...)local a={}for i,v in pairs{...}do a[i]=tostring(v)end return table.concat(a,'\t')end
local function verbose(...)if _VERBOSE then print(('[Verbose]: %s'):format(p_concat(...)))end end
local function verror(...)if _VERBOSE then print(('[V-Error]: %s'):format(p_concat(...)))end end

verbose('Attempting to get current process title.')
local old_title, old_title_err = uv.get_process_title()

if old_title then
  verbose(('  Process title is %q.'):format(old_title))
else
  verror(('  Failed getting the process title; %s'):format(old_title_err))
end

local new_title_ok, new_title_err
if not old_title then
  verbose('Getting process title failed so won\'t try to change it.')
else
  verbose('Attempting to change current process title.')
  new_title_ok, new_title_err = uv.set_process_title('Cool process title changing code :)')
  if new_title_ok then
    verbose('  Changed current process title.')
  else
    verror(('  Failed setting new process title; %s'):format(new_title_err))
  end
end

if _DISABLE_EXTRA_WAIT == true then
  verbose('Sleeping for 2.5 seconds disabled.')
else
  print('[Main]: Sleeping for 2.5 seconds.')
  uv.sleep(2500)
end

verbose('Getting system total memory size.')
local sys_total_mem, sys_total_mem_err = uv.get_total_memory()
local sys_total_mem_bs
local misc_mem_pad_num, misc_mem_pad_suf = 0, 0
if sys_total_mem then
  sys_total_mem_bs = byteSize(sys_total_mem,_USE_I_BYTES)
  verbose(('  System total memory size is %s (%iB)'):format(sys_total_mem_bs,sys_total_mem))
  misc_mem_pad_num = (#sys_total_mem_bs:match('^(%d*)'))
  misc_mem_pad_suf = (#sys_total_mem_bs:match('([A-Zi]*)$'))
else
  verror(('  Failed getting system total memory size; %s'):format(sys_total_mem_err))
end

verbose('Getting system free memory size.')
local sys_free_mem, sys_free_mem_err = uv.get_free_memory()
local sys_free_mem_bs
if sys_free_mem then
  sys_free_mem_bs = byteSize(sys_free_mem,_USE_I_BYTES)
    :gsub('^(%d*)', function(x)return((' '):rep(misc_mem_pad_num):sub(#x+1)..x)end)
    :gsub('([A-Zi]+)$', function(x)return(x..(' '):rep(misc_mem_pad_suf):sub(#x+1))end)
  verbose(('  System free memory size is %s (%iB)'):format(sys_free_mem_bs,sys_free_mem))
else
  verror(('  Failed getting system free memory size; %s'):format(sys_free_mem_err))
end

local sys_used_mem, sys_used_mem_bs
if not(sys_total_mem and sys_free_mem)then
  verbose('Getting system total/free memory failed so won\'t calculate used memory.')
else
  verbose('Calculating used system memory size.')
  sys_used_mem = sys_total_mem - sys_free_mem
  sys_used_mem_bs = byteSize(sys_used_mem,_USE_I_BYTES)
    :gsub('^(%d*)', function(x)return((' '):rep(misc_mem_pad_num):sub(#x+1)..x)end)
    :gsub('([A-Zi]+)$', function(x)return(x..(' '):rep(misc_mem_pad_suf):sub(#x+1))end)
  verbose(('  Used system memory size is %s (%iB)'):format(sys_used_mem_bs,sys_used_mem))
end

local sys_used_mem_prc, sys_free_mem_prc
local sys_mem_str_pat
if not sys_total_mem then
  verbose('No total system memory size found so won\'t calculate memory percentages.')
else
  verbose('Calculcating system free/used memory percentages.')
  do
    local len_0, len_1, len_2, len_3 = 0, #tostring(sys_total_mem or 0), #tostring(sys_free_mem or 0), #tostring(sys_used_mem or 0)
    len_0 = (len_0<len_1 and len_1 or len_0)
    len_0 = (len_0<len_2 and len_2 or len_0)
    len_0 = (len_0<len_3 and len_3 or len_0)
    sys_mem_str_pat = ('%%%ii'):format(len_0)
  end
  if not sys_free_mem then
    verror('  System total memory size was found without free memory size.')
  else
    sys_free_mem_prc = calcPercent(sys_total_mem,sys_free_mem)
    verbose(('  System free memory size in percents is %s'):format(sys_free_mem_prc))
    if not sys_used_mem then
      verror('  System total and free memory sizes found without used memory size.')
    else
      sys_used_mem_prc = calcPercent(sys_total_mem,sys_used_mem)
      verbose(('  System used memory size in percents is %s'):format(sys_used_mem_prc))
    end
  end
end

verbose('Getting system uptime.')
local sys_uptime, sys_uptime_err = uv.uptime()
local sys_uptime_str
if not sys_uptime then
  verror(('  Failed getting system uptime; %s'):format(sys_uptime_err))
else
  do
    local days = math.floor(sys_uptime/60/60/24)
    local hours = math.floor(sys_uptime/60/60%24)
    local mins = math.floor(sys_uptime/60%60)
    local dayss = (days>0 and('%id '):format(days)or'')
    sys_uptime_str = ('%s%02i:%02i'):format(dayss,hours,mins)
  end
  verbose(('  System uptime is %s (%is)'):format(sys_uptime_str,sys_uptime))
end

verbose('Getting system uname.')
local sys_uname, sys_uname_err = uv.os_uname()
local sys_kernel_release_str, sys_kernel_name_str, sys_kernel_str
if not sys_uname then
  verror(('  Failed getting system uname; %s'):format(sys_uname_err))
else
  if not sys_uname.release then
    verror('  System uname data did not contain \'release\' value.')
  else
    sys_kernel_release_str = (sys_uname.release):match('^([^%-]*)')
    verbose(('  System kernel version is %q (%s)'):format(sys_kernel_release_str,sys_uname.release))
  end
  if not sys_uname.sysname then
    verror('  System uname data did not contain \'sysname\' value.')
  else
    sys_kernel_name_str = (sys_uname.sysname)
    verbose(('  System kernel name is %q.'):format(sys_kernel_name_str))
  end
  if sys_kernel_name_str and sys_kernel_release_str then
    sys_kernel_str = ('%s %s'):format(sys_kernel_name_str,sys_kernel_release_str)
    verbose(('  System kernel is %q.'):format(sys_kernel_str))
  end
end

local sys_os_name
if sys_uname and sys_uname.sysname then
  verbose('Attempting to guess current OS name.')
  verbose(('  Kernel name is %s.'):format(escapeStr(sys_uname.sysname)))
  if sys_uname.sysname == 'Windows_NT' then
    sys_os_name = sys_uname.version
  elseif sys_uname.sysname == 'Linux' then
    for _,path in pairs{'/etc/os-release','/usr/lib/os-release'}do
      local f = io.open(path,'rb')
      if f then
        for line in f:lines()do
          local name,val = line:match('^([^=]*)=(.-)$')
          if name and val then
            name, val = name:match('^%s*(.-)%s*$'), val:match('^%s*(.-)%s*$')
            if name == 'ID' and val~='' then
              sys_os_name = val
              break
            end
          end
        end
        f:close()
      end
      if sys_os_name then break end
    end
  end
  if not sys_os_name then
    verbose('  Failed to guess OS name.')
  else
    verbose(('  Guessing OS name to be %s.'):format(escapeStr(sys_os_name)))
  end
else
  verbose('Won\'t guess OS name due to getting system uname failed.')
end

verbose('Getting system hostname.')
local sys_hostname, sys_hostname_err = uv.os_gethostname()
if not sys_hostname then
  verror(('  Failed getting system hostname; %s'):format(sys_hostname_err))
else
  verbose(('  System hostname is %q.'):format(sys_hostname))
end

verbose('Getting system password file info.')
local sys_passwd, sys_passwd_err = uv.os_get_passwd()
local sys_username
if not sys_passwd then
  verror(('  Failed getting system password file info; %s'):format(sys_passwd_err))
else
  if not sys_passwd.username then
    verror('  System password file info did not contain \'username\' value.')
  else
    sys_username = (sys_passwd.username)
    verbose(('  Current username is %q.'):format(sys_username))
  end
end

verbose('Getting CPU model info.')
local sys_cpu_info, sys_cpu_info_err = uv.cpu_info()
local sys_cpu_model_str
if not sys_cpu_info then
  verror(('  Failed getting CPU info; %s'):format(sys_cpu_info_err))
else
  if #sys_cpu_info<1 then
    verror('  CPU info list was empty.')
  else
    local cpu_model
    for i,v in pairs(sys_cpu_info)do
      if type(v.model)=='string' and #v.model>0 then
        local model = (v.model) :gsub('%([^%(%)]-%)',''):gsub(' @.*$',''):gsub(' CPU$',''):gsub('^CPU ','')
                                :gsub('^.*(AMD )','%1'):gsub(' with.*$',''):gsub(' %S*%-Core.-$','')
        if #model>0 then cpu_model=model break end
      end
    end
    if not cpu_model then
      verror('  No valid model name found from CPU list.')
    else
      sys_cpu_model_str = cpu_model
      verbose(('  System CPU model is %s.'):format(escapeStr(sys_cpu_model_str)))
    end
  end
end

verbose('Generating a random 16 byte string.')
local misc_random, misc_random_err = uv.random(16)
local misc_random_str
if not misc_random then
  verror(('  Failed generating random 16 byte string; %s'):format(sys_passwd_err))
else
  misc_random_str = escapeStr(misc_random)
  verbose(('  Generated random 16 byte string is %s.'):format(misc_random_str))
end

print('[Main]: ')
print('[Main]: System info:')
if sys_hostname then
  print(('[Main]:   Hostname : %s'):format(sys_hostname))
end
if sys_username then
  print(('[Main]:   Username : %s'):format(sys_username))
end
if sys_uptime_str then
  print(('[Main]:   Uptime   : %s'):format(sys_uptime_str))
end
if sys_os_name then
  print(('[Main]:   OS       : %s'):format(sys_os_name))
end
if sys_kernel_str then
  print(('[Main]:   Kernel   : %s'):format(sys_kernel_str))
end
if sys_cpu_model_str then
  print(('[Main]:   CPU      : %s'):format(sys_cpu_model_str))
end
if sys_mem_str_pat and sys_total_mem and sys_total_mem_bs then
  print('[Main]:   Memory   :')
  print(('[Main]:     Total  : %s (-------|'..sys_mem_str_pat..'B)'):format(sys_total_mem_bs,sys_total_mem))
  if sys_free_mem_bs and sys_free_mem_prc and sys_free_mem then
    print(('[Main]:     Free   : %s (%7s|'..sys_mem_str_pat..'B)'):format(sys_free_mem_bs,sys_free_mem_prc,sys_free_mem))
  end
  if sys_used_mem_bs and sys_used_mem_prc and sys_used_mem then
    print(('[Main]:     Used   : %s (%7s|'..sys_mem_str_pat..'B)'):format(sys_used_mem_bs,sys_used_mem_prc,sys_used_mem))
  end
end
if misc_random_str then
  print(('[Main]:   Random   : %s'):format(misc_random_str))
end
print('[Main]: ')
