System : info 
 Static hostname: rocky-8gb-nbg1-2
       Icon name: computer-vm
         Chassis: vm 🖴
      Machine ID: 19320520253248bb809ab0eb1cf4d3c6
         Boot ID: 5099358de8ec477392c87854c572069a
  Virtualization: kvm
Operating System: Rocky Linux 9.7 (Blue Onyx)
     CPE OS Name: cpe:/o:rocky:rocky:9::baseos
          Kernel: Linux 5.14.0-611.16.1.el9_7.x86_64
    Architecture: x86-64
 Hardware Vendor: Hetzner
  Hardware Model: vServer
Firmware Version: 20171111
               Local time: Thu 2026-01-15 16:00:11 PKT
           Universal time: Thu 2026-01-15 11:00:11 UTC
                 RTC time: Thu 2026-01-15 11:00:10
                Time zone: Asia/Karachi (PKT, +0500)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no


-----

Apache 


    Loaded: loaded (/usr/lib/systemd/system/httpd.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/httpd.service.d
             └─php-fpm.conf
     Active: active (running) since Thu 2026-01-15 16:03:39 PKT; 1min 28s ago
       Docs: man:httpd.service(8)
   Main PID: 689 (httpd)
     Status: "Total requests: 0; Idle/Busy workers 100/0;Requests/sec: 0; Bytes served/sec:   0 B/sec"
      Tasks: 177 (limit: 47674)
     Memory: 21.6M (peak: 21.9M)
        CPU: 258ms
     CGroup: /system.slice/httpd.service
             ├─689 /usr/sbin/httpd -DFOREGROUND
             ├─771 /usr/sbin/httpd -DFOREGROUND
             ├─772 /usr/sbin/httpd -DFOREGROUND
             ├─773 /usr/sbin/httpd -DFOREGROUND
             └─774 /usr/sbin/httpd -DFOREGROUND

Jan 15 16:03:39 rocky-8gb-nbg1-2 systemd[1]: Starting The Apache HTTP Server...
Jan 15 16:03:39 rocky-8gb-nbg1-2 httpd[689]: AH00558: httpd: Could not reliably determine the server's fully qu>
Jan 15 16:03:39 rocky-8gb-nbg1-2 systemd[1]: Started The Apache HTTP Server.
Jan 15 16:03:39 rocky-8gb-nbg1-2 httpd[689]: Server configured, listening on: port 443, port 80


-------
Maria Db 


     Loaded: loaded (/usr/lib/systemd/system/mariadb.service; enabled; preset: disabled)
    Drop-In: /etc/systemd/system/mariadb.service.d
             └─migrated-from-my.cnf-settings.conf
     Active: active (running) since Thu 2026-01-15 16:03:40 PKT; 2min 10s ago
       Docs: man:mariadbd(8)
             https://mariadb.com/kb/en/library/systemd/
    Process: 690 ExecStartPre=/bin/sh -c [ ! -e /usr/bin/galera_recovery ] && VAR= ||   VAR=`/usr/bin/galera_re>
    Process: 964 ExecStartPost=/bin/rm -f /run/mariadb/wsrep-start-position /run/mariadb/wsrep-new-cluster (cod>
   Main PID: 766 (mariadbd)
     Status: "Taking your SQL requests now..."
      Tasks: 8 (limit: 58997)
     Memory: 156.9M (peak: 157.4M)
        CPU: 383ms
     CGroup: /system.slice/mariadb.service
             └─766 /usr/sbin/mariadbd

Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] InnoDB: File './ibtmp1' size is no>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] InnoDB: log sequence number 45576;>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] InnoDB: Loading buffer pool(s) fro>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] Plugin 'FEEDBACK' is disabled.
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] InnoDB: Buffer pool(s) load comple>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] Server socket created on IP: '127.>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Warning] 'proxies_priv' entry '@% mysql@>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: 2026-01-15 16:03:40 0 [Note] /usr/sbin/mariadbd: ready for conn>
Jan 15 16:03:40 rocky-8gb-nbg1-2 mariadbd[766]: Version: '10.11.15-MariaDB'  socket: '/var/lib/mysql/mysql.sock>
Jan 15 16:03:40 rocky-8gb-nbg1-2 systemd[1]: Started MariaDB 10.11.15 database server.

------

Asterisk 


    Loaded: loaded (/etc/systemd/system/asterisk.service; enabled; preset: disabled)
     Active: active (running) since Thu 2026-01-15 16:03:40 PKT; 2min 51s ago
   Main PID: 965 (asterisk)
      Tasks: 68 (limit: 47674)
     Memory: 97.0M (peak: 97.8M)
        CPU: 3.299s
     CGroup: /system.slice/asterisk.service
             └─965 /usr/sbin/asterisk -f -vvvg

Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] WARNING[965]: loader.c:2503 load_modules: Mod>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] ERROR[965]: loader.c:2524 load_modules: res_t>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] ERROR[965]: loader.c:2524 load_modules: cel_s>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: [Jan 15 16:03:42] ERROR[965]: loader.c:2524 load_modules: cdr_s>
Jan 15 16:03:42 rocky-8gb-nbg1-2 asterisk[965]: Asterisk Ready.




-----------------
Manual cron running as crontab -l
-----------------
Fix : 


FINAL RECOMMENDED CRONTAB (EL9 SAFE)
Step 1: Replace your crontab with THIS
cat <<'EOF' > /tmp/vicidial.cron
### ============================
### VICIDIAL PRODUCTION CRONTAB
### ============================

# --- VICIDIAL KEEPALIVE (THE ONLY CORE LOOP) ---
* * * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_keepalive_ALL.pl

# --- MAINTENANCE & HEALTH ---
*/15 * * * * /usr/bin/perl /usr/share/astguiclient/AST_DB_check_tables.pl
2 1 * * * /usr/bin/perl /usr/share/astguiclient/AST_cleanup_agent_log.pl
1 1 * * * /usr/bin/perl /usr/share/astguiclient/ADMIN_archive_log_tables.pl --daily
EOF


Apply it:

crontab /tmp/vicidial.cron


Verify:

crontab -l


-----------------
---

